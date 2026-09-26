# HaveThis

Point the camera at a menu. The phone reads the text, drops anything that is not a dish, and Jev picks what to order.

The photo stays on the device. Only dish names are sent to Jev.

Internal TestFlight, same path as SayThis. Team `DNQVHANQBU`, bundle `com.praveenmurugesan.HaveThis`.

## Generate

```bash
brew install xcodegen
xcodegen generate
open HaveThis.xcodeproj
```

The scoring key is the build setting `JEV_API_KEY`. It is injected in CI and is not committed.
