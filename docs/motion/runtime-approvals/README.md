# Runtime approvals

The default harness does not link Rive, Lottie, dotLottie, or other animation
runtimes. When a real app needs one, copy
`../runtime-approval-template.md` to `<engine>.approval.md` in this folder and
fill it out before adding the package.

The lint gate looks for `*.approval.md` files here. This README is only a
directory marker and does not approve a runtime.
