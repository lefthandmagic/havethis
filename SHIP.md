# HaveThis — before the store

Updated 3 Oct 2026. Knock a line to done when it lands.

## Done in the app

- [x] Paywall, HaveThis Plus (monthly and yearly), restore, and a pack of 10 scans. Yearly is listed first.
- [x] Scans stay open until the App Store products actually load, so this TestFlight build is not bricked. Once they load, a scan without an allowance opens the paywall.
- [x] A scan is only counted after Jev returns a menu. A failed call does not spend one.
- [x] Local allowance on the phone (stand-in until the server ledger).
- [x] Mollusk and mushroom skips are off until turned on in Settings. Protein, fiber, and saturated fat still rank the list.
- [x] Ranked screen says the numbers are estimated from the dish name, not a lab value.
- [x] Photo clock, Jev clock, and call count are hidden outside debug builds.
- [x] A menu past 20 dishes says how many were not scored, and a second photo adds to the same list.
- [x] In-app privacy page: photo stays on the phone, dish names go to Jev, not medical advice. Camera text already says the photo stays on the device. Encryption export stays off.
- [x] Privacy manifest lists dish names as other user content, not linked to the user, not used for tracking.
- [x] Support link in Settings.
- [x] Distinct failures: no dishes, missing key, no connection, scoring down, scoring failed, empty allowance. A merge that fails stays on the ranked screen and shows the reason.
- [x] Scoring screen: one **Have this** pick, two backups, each with a score out of 10, a one-line reason, and Low / Moderate / High for protein, fiber, and saturated fat. The rest of the menu shows the score only.

## Still open

- [ ] **Server in front of Jev, and the scan ledger on that server.** The key is still in the app build. Do this before a public release. Sign in with Apple comes with it, so a reinstall keeps the allowance.
- [ ] Create the three products in App Store Connect: `com.praveenmurugesan.HaveThis.plus.monthly`, `com.praveenmurugesan.HaveThis.plus.yearly`, `com.praveenmurugesan.HaveThis.scans.10`. Local StoreKit config is `HaveThis/Resources/HaveThis.storekit`.
- [ ] Host the privacy page at a public URL and put that URL on the App Store listing. The in-app page is the text.
- [ ] Swap the support address if `lefthandmagic@gmail.com` should not be the public one.

## After the first version

- [ ] Alcohol flag
- [ ] One “have this” pick that can be shared
- [ ] Remember a restaurant
- [ ] More nutrients than protein, fiber, and saturated fat
