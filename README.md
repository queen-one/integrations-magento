# Queen One Connect for Magento 2

`queen-one/module-connect` (Magento module `QueenOne_Connect`) is the managed-pilot Queen One
integration for Magento 2. It publishes storefront page, product, cart and logged-in identity
events through Queen One Tag and delivers persisted orders to Bridge through a signed backend
outbox.

It is packaged separately from the legacy Rejoiner plugin (`rejoiner/module-acr`, module
`Rejoiner_Acr`). It shares no PHP classes, configuration paths, database tables, cron jobs,
routes or customer-data sections with the legacy Rejoiner releases of that package, and it
replaces that package's `dev-queen-one` pilot build (see the migration steps below). Store
provisioning is still performed with Queen One Ops for this pilot; self-service onboarding is
a later milestone.

## Production defaults

The module defaults to the production services below. Merchants cannot edit these URLs
in Magento Admin.

- Tag: `https://queen-one-init.queen.one/queen-one.js`
- Bridge: `https://integrations.queen.one`

Staging operators may override the hidden configuration paths at the required scope:

```sh
bin/magento config:set checkout/queen_one_connect/tag_url \
  https://queen-one-init-staging.queen-one.workers.dev/queen-one.js
bin/magento config:set checkout/queen_one_connect/bridge_url \
  https://integrations.staging.queen.one
bin/magento cache:clean config layout full_page
```

Do not carry staging overrides into a production deployment. Verify the effective values
with `bin/magento config:show` before enabling delivery. An empty result means the module
uses its built-in production default; every non-empty override must match the approved
environment.

The built-in production and staging Tag environments include their complete CSP
dependencies. A custom Tag host receives only its own `script-src` origin; deployments
using another environment must add explicit Magento CSP rules for that environment's
Core, Collector and Frames origins before enabling storefront tracking.

## Managed production installation

Install a reviewed revision of `queen-one/module-connect` through the customer's Composer
repository and commit the resulting `composer.lock`. The locked source reference, not a moving
branch name, is the release boundary for the pilot. Do not run an unreviewed update on a
production store.

After installing the module and taking the normal database backup:

```sh
bin/magento module:enable QueenOne_Connect
bin/magento setup:upgrade
bin/magento setup:di:compile
bin/magento setup:static-content:deploy
bin/magento cache:clean
```

For an upgrade, clean generated static/view-preprocessed artifacts through the customer's
normal deployment procedure before static-content deployment so files removed by an older
module revision cannot remain as stale symlinks.

### Moving a store off the `rejoiner/module-acr` `dev-queen-one` build

Earlier pilot builds shipped this code as `rejoiner/module-acr` `dev-queen-one`, module
`Rejoiner_Acr`. Replace that requirement with `queen-one/module-connect` in a single
deployment, enable `QueenOne_Connect` and run `setup:upgrade`. Configuration under
`checkout/queen_one_connect/*`, activation boundaries and outbox rows carry over because the
paths and table names are unchanged. Never install both builds together: they register the
same layout block, cron job and customer-data section, and Composer refuses the combination.
The pilot build's legacy database objects stay in place, unused: the
`rejoiner_acr_success_orders` table, the `quote.promo` and
`newsletter_subscriber.added_to_rejoiner` columns, and the `Rejoiner_Acr` row in
`setup_module`. Rolling back is the reverse swap in a single deployment: require
`rejoiner/module-acr` `dev-queen-one` in place of `queen-one/module-connect`, enable
`Rejoiner_Acr` and run `setup:upgrade`.

Queen One Ops provisions the Bridge integration, Magento store binding and unique HMAC
secret. At the target **store view** scope under **Stores → Configuration → Sales →
Checkout → Queen One Connect**, configure the Site ID, Bridge Integration ID and encrypted
HMAC secret. Storefront and backend delivery can be enabled independently.

Activate backend delivery only after configuration has been verified:

```sh
bin/magento queenone:orders activate STORE_ID
bin/magento queenone:orders run STORE_ID
bin/magento queenone:orders status STORE_ID
```

Activation starts with orders created from that boundary forward. No history is sent
unless an operator explicitly runs the bounded backfill command. Standard Magento cron
must be running.

See [the managed production runbook](docs/managed-production-pilot.md),
[backend order operations](docs/backend-orders.md), and
[storefront validation](docs/storefront-tracking-validation.md).

## Supported pilot lane and known limitations

- Magento Open Source 2.4.9 is the primary tested lane; 2.4.8-p5 is the compatibility lane.
- Storefront tracking uses Magento RequireJS/customer-data and does not support Hyvä or
  headless storefronts in this release.
- Guest email capture and cart return URLs are deferred.
- Bundle/grouped/custom product structures and fractional quantities are not supported.
- Each Magento store requires its own Bridge integration binding.
- Catalog setup uses a manually created Magento integration token and the approved secure
  Ops process. The merchant must explicitly enable standalone integration bearer tokens.

## Local development

Prerequisites are Docker Desktop with at least 8 GB allocated, Git, Make and Adobe
Marketplace Composer credentials. Bootstrap the default Magento 2.4.9 lab with:

```sh
make magento-auth
make magento-install
make magento-smoke
```

Use `MAGENTO_VERSION=2.4.8-p5 make magento-install` for the compatibility lane. Generated
Magento files and credentials live under `.local/` and are excluded from Git. See the
[Magento lab guide](dev/magento/README.md) for the full workflow.
