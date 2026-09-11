fx_version "cerulean"
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author "GFX Development"
description "Multi-framework bridge for RedM (VORP, RSG, RedEM:RP)"
-- 1.1.0: added client exports OnMoneyChange + OnNeedsChange (event-driven money/needs);
--        VORP TriggerCallback transport fix. Feature scripts (gfxr-hud) require these.
-- 1.1.1: inventory detection no longer misses a resource still in 'starting'
--        state on onResourceStart (gfxr-inventory late-start fix).
version '1.1.1'

shared_scripts { 'shared/*.lua' }
client_scripts { 'client/*.lua' }
server_scripts { 'server/*.lua' }

-- ESCROW: framework/inventory/SQL detection table (shared/main.lua) stays open
-- so server owners can add their own framework names; client/server logic is
-- encrypted but still runs.
escrow_ignore {
    'shared/main.lua',
}

dependency '/assetpacks'
dependency '/assetpacks-redm'
