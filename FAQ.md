# FAQ

Plain-language answers for non-technical readers. Technical detail: [02 stack](docs/02-stack.md).

## Why no npm (heavy JavaScript toolkits) for the website?

- **Fewer parts that can break.** One language, shipped as one piece. A typical npm setup pulls in 1,000+ outside packages, each one code we didn't write and must trust.
- **Safer.** Attackers often target those outside packages. Fewer packages, fewer ways in.
- **Less upkeep.** npm tools go out of date within months. This approach keeps working for years.
- **Faster pages.** The page arrives ready to show, quick even on weak phones.
- **Cheaper to build and change.** Less code: developers and AI assistants work faster, with fewer mistakes.

## Why Docker Swarm, not Kubernetes, to run the servers?

- **Kubernetes is built for big companies:** hundreds of services, large teams, a dedicated specialist just to keep it running.
- **Swarm comes with Docker.** Almost nothing to install or maintain: cheaper and quicker to start.
- **Lower bills.** Runs on the few servers already paid for; Kubernetes often adds a monthly fee.
- **Fewer outages.** Fewer moving parts, fewer things that go wrong.
- **Switching later is possible.** If the product outgrows Swarm, moving is a planned project, not a rebuild.

**In short:** both keep the product cheaper, safer and faster to build at the start, and both can be revisited if it grows a lot.
