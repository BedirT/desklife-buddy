#!/bin/bash -p
# Epic 3 story 1: raw-sensing / egress import guard.
#
# Fails the build if any of the nine protected raw classes can reach product
# code: camera, mic/speech, HealthKit, CoreLocation, screen-capture/AX-text,
# Vision/OCR, CoreMotion, photos/media, network-egress/transport — plus the
# dynamic-lookup category (runtime resolution must never smuggle raw types).
# Raw pixels, audio, OCR, health samples, coordinates, titles, and fine motion
# must never enter Domain, persistence, logs, crash data, export, transport,
# or prompts, so the scan covers every product target (App, Packages,
# AppTests) plus entitlements, privacy keys, build-config files, and the Xcode
# project — with no per-surface exclusions.
#
# ALLOWLIST: scripts/support/* tooling (dump_ax, runtime_probe, shot/ui
# drivers) captures AX titles and pixels BY DESIGN for development snapshots.
# It lives outside the scan scope below. Product code must never import or
# shell out to those helpers, so references to that tooling path inside
# product targets are themselves a violation (screen-capture class).
#
# Exemptions (fail-closed, narrow by construction): a hit is honored ONLY when
# its own line carries `// RAWGUARD-ALLOW: <reason>` with a non-empty reason.
# A bare marker, or a marker on any other line, still fails the build.
#
# Adjacent coverage this guard integrates with instead of duplicating:
# - scripts/check-protocol-configuration.sh: sensor-free fallback contract,
#   permission-free inference lock, raw-candidate memory-only transport rule,
#   sender-outbox backup/export/log exclusion.
# - scripts/check-motion-assets.sh: rejects remote motion-asset URLs.
# - Domain HistoryExport vocabulary lock, SwiftData store round-trip tests,
#   silent-notification contract test: semantic locks, not source bans.
set -euo pipefail

. "$(dirname "$0")/lib.sh"
cd "$ROOT"

# Tests point the guard at a scratch tree via RAW_IMPORTS_SCAN_ROOT.
scan_root="${RAW_IMPORTS_SCAN_ROOT:-$ROOT}"

swift_roots=()
for dir in App Packages AppTests; do
  [[ -d "$scan_root/$dir" ]] && swift_roots+=("$scan_root/$dir")
done

config_files=()
for dir in App Packages AppTests App.xcodeproj; do
  [[ -d "$scan_root/$dir" ]] || continue
  while IFS= read -r found; do
    config_files+=("$found")
  done < <(find "$scan_root/$dir" \
    \( -path '*/.build' -o -path '*/DerivedData' -o -path '*/artifacts' -o -path '*__Snapshots__*' \) -prune \
    -o -type f \( -name '*.entitlements' -o -name '*.plist' -o -name 'project.pbxproj' -o -name '*.xcconfig' \) -print 2>/dev/null)
done

violations=()
exemptions=0

# A hit line is exempt ONLY with a same-line `// RAWGUARD-ALLOW: <reason>`.
collect() {
  local label="$1" hits="$2"
  local kept=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ RAWGUARD-ALLOW:[[:space:]]*[^[:space:]] ]]; then
      ((exemptions += 1)) || true
    else
      kept+=("$line")
    fi
  done <<<"$hits"
  if ((${#kept[@]})); then
    violations+=("[$label]")
    for line in "${kept[@]}"; do
      violations+=("  $line")
    done
  fi
}

check_swift() {
  local label="$1" pattern="$2"
  (( ${#swift_roots[@]} )) || return 0
  local hits
  if hits="$(rg -n --no-heading -e "$pattern" --glob '*.swift' "${swift_roots[@]}" 2>/dev/null)"; then
    collect "$label" "$hits"
  fi
}

# Plists are decoded through plutil first so XML-entity and binary encodings
# cannot evade the key scan; pbxproj/xcconfig files are scanned raw.
check_config() {
  local label="$1" pattern="$2"
  (( ${#config_files[@]} )) || return 0
  local plain=() plist=()
  local file
  for file in "${config_files[@]}"; do
    case "$file" in
      *.plist | *.entitlements) plist+=("$file") ;;
      *) plain+=("$file") ;;
    esac
  done
  local hits
  if ((${#plain[@]})) && hits="$(rg -n --no-heading -e "$pattern" "${plain[@]}" 2>/dev/null)"; then
    collect "$label" "$hits"
  fi
  local decoded_hits=""
  for file in "${plist[@]:-}"; do
    [[ -n "$file" ]] || continue
    local rel="${file#"$scan_root"/}" decoded
    if command -v plutil >/dev/null 2>&1 && decoded="$(plutil -convert xml1 -o - "$file" 2>/dev/null)"; then
      local match
      if match="$(printf '%s' "$decoded" | rg -n -e "$pattern" 2>/dev/null)"; then
        while IFS= read -r line; do
          decoded_hits+="$rel:$line"$'\n'
        done <<<"$match"
      fi
    elif hits="$(rg -n --no-heading -e "$pattern" "$file" 2>/dev/null)"; then
      decoded_hits+="$hits"$'\n'
    fi
  done
  if [[ -n "$decoded_hits" ]]; then
    collect "$label" "$decoded_hits"
  fi
  return 0
}

# 1. Camera.
check_swift "camera" 'import\s+AV(Foundation|Kit)|AVCapture'
# 2. Microphone / speech, including low-level audio units and HAL I/O.
check_swift "mic/speech" 'import\s+(AVFAudio|AudioUnit|Speech)|AVAudio|AudioToolbox|CoreAudio|SFSpeech|AudioComponent|AudioUnitRender|AudioOutputUnit|AudioUnitInitialize|kAudioUnit|AudioDeviceIOProc|AudioObjectProperty'
# 3. HealthKit. Enumerated type stems (not a bare HK prefix) so lookalikes
# such as HKDF key-derivation labels stay clean.
check_swift "healthkit" 'import\s+HealthKit|\bHK(Health|Object|Deleted|Sample|Quantity|Category|Characteristic|Correlation|Workout|LiveWorkout|Observer|Statistics|Activity|Heartbeat|Electrocardiogram|Authorization|Query|Unit|Source|Device|Series)[A-Za-z]*'
# 4. CoreLocation. (CGPoint layout math is untouched: only CL* sensing types.)
check_swift "location" 'import\s+CoreLocation|\bCL(Location|Monitor|Beacon|Region|Geocoder)'
# 5. Screen capture / AX text. CoreGraphics geometry stays allowed; capture,
# pixel-readback, and AX-read symbols are banned, plus tooling-path refs.
check_swift "screen-capture/ax" 'import\s+(ScreenCaptureKit|ApplicationServices)|SCStream|SCShareableContent|SCScreenshotManager|CGWindowListCopyWindowInfo|CGWindowListCreateImage|CGPreflightScreenCaptureAccess|CGRequestScreenCaptureAccess|CGDisplayCreateImage|CGDisplayStream|CGWindowID|kCGWindow|AXUIElement|\bkAX[A-Z]|screencapture|scripts/support'
# 6. Vision / OCR.
check_swift "vision/ocr" 'import\s+Vision(Kit)?|\bVN[A-Z]'
# 7. CoreMotion.
check_swift "motion" 'import\s+CoreMotion|CMMotion|CMPedometer|CMAltimeter|CMSensorRecorder'
# 8. Photos / media library. (NSOpenPanel bundle picking is untouched.)
check_swift "photos" 'import\s+Photos(UI)?|PHPhotoLibrary|PHAsset|PHImageManager|PHPicker|PhotosPicker'
# 9. Network egress / transport: sockets, cloud sync, and web views.
# (Asset-manifest remote-URL rejection lives in check-motion-assets.sh; this
# bans runtime transport APIs and entitlements.)
check_swift "network" 'URLSession|URLRequest|import\s+(Network|CloudKit|WebKit)|NWConnection|NWPathMonitor|NWListener|CK(Container|Record|Database|Query|Asset|Subscription)|WKWebView|import\s+MetricKit|MXMetric'
# 10. Dynamic lookup: runtime resolution, bundle loading, and re-export are
# never legitimate in this product, so they are banned as a category.
check_swift "dynamic-lookup" 'NSClassFromString|dlopen|dlsym|@_exported|NSBundle|\bBundle\.[A-Za-z]+\.load\(\)|\bbundle\.load\(\)'

# Entitlements: the sandbox stays network/camera/mic/health/location-free.
check_config "entitlement" 'com\.apple\.security\.device\.camera|com\.apple\.security\.device\.audio-input|com\.apple\.developer\.healthkit|com\.apple\.security\.personal-information\.location|com\.apple\.security\.network\.(client|server)'
# Privacy usage-description keys and transport-security exceptions.
check_config "privacy-key" 'NSCameraUsageDescription|NSMicrophoneUsageDescription|NSSpeechRecognitionUsageDescription|NSHealthShareUsageDescription|NSHealthUpdateUsageDescription|NSLocation(TemporaryUsageDescriptionDictionary|(WhenInUse|Always|AlwaysAndWhenInUse)?UsageDescription)|NSMotionUsageDescription|NSPhotoLibrary(Add)?UsageDescription|NSAppTransportSecurity'

# 11. Evidence confinement (Epic 3 story 3): Evidence* and Fused* types are
# Class 0 (memory-only, never Codable) and must never reach App/AppTests
# targets or Domain persistence/export/transport files. Domain's own
# Evidence*.swift definitions and every *Tests* tree (fakes live test-side)
# are out of scope. Story 4 (closed firewall) will consume the bus from
# named Domain files: those files carry a same-line
# `// RAWGUARD-ALLOW: <reason>` exemption, like every other category above.
evidence_pattern='EvidenceAtom(ID)?|EvidenceBus|EvidenceFusion|EvidenceProposal(Error)?|EvidenceAdmission(Rejection)?|EvidenceProvenance|EvidenceKind|EvidenceSource|EvidenceQuality|EvidenceConfidence|EvidenceCoverage|EvidenceReading|EvidenceFailureReason|EvidenceIndependenceGroup|FusedReading|FusedAssessment'
evidence_files=()
for dir in App AppTests; do
  [[ -d "$scan_root/$dir" ]] || continue
  while IFS= read -r found; do
    evidence_files+=("$found")
  done < <(find "$scan_root/$dir" \
    \( -path '*/.build' -o -path '*/DerivedData' -o -path '*/artifacts' -o -path '*__Snapshots__*' \) -prune \
    -o -type f -name '*.swift' -print 2>/dev/null)
done
if [[ -d "$scan_root/Packages" ]]; then
  while IFS= read -r found; do
    case "$found" in
      */Sources/Domain/Evidence*.swift) continue ;;
      */Tests/*|*Tests.swift) continue ;;
      *__Snapshots__*) continue ;;
    esac
    evidence_files+=("$found")
  done < <(find "$scan_root/Packages" \
    \( -path '*/.build' -o -path '*/DerivedData' -o -path '*/artifacts' \) -prune \
    -o -type f -name '*.swift' -print 2>/dev/null)
fi
if ((${#evidence_files[@]})); then
  hits=""
  if hits="$(rg -n --with-filename --no-heading -e "$evidence_pattern" "${evidence_files[@]}" 2>/dev/null)"; then
    collect "evidence-confinement" "$hits"
  fi
fi

if ((${#violations[@]})); then
  printf 'Raw import guard violations:\n' >&2
  for violation in "${violations[@]}"; do
    printf '  %s\n' "$violation" >&2
  done
  exit 1
fi

if ((exemptions > 0)); then
  echo "check-raw-imports: OK ($exemptions exemption(s) honored)"
else
  echo "check-raw-imports: OK"
fi
