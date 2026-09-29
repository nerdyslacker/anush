const test = require("node:test")
const assert = require("node:assert/strict")
const model = require("../shell/components/Tailscale/TailscaleModel.js")

test("normalizes status, peers, health, and exit nodes", () => {
  const result = model.parseStatus(JSON.stringify({
    BackendState: "Running",
    Health: ["key expiring"],
    Self: {
      HostName: "laptop",
      DNSName: "laptop.example.ts.net.",
      UserID: 7,
      TailscaleIPs: ["100.64.0.1", "fd7a:115c:a1e0::1"],
      Capabilities: ["https://tailscale.com/cap/file-sharing"]
    },
    Peer: {
      node1: { HostName: "server", DNSName: "server.example.ts.net.",
        UserID: 7, Online: true, ExitNodeOption: true,
        TailscaleIPs: ["100.64.0.2"], RxBytes: 1024, TxBytes: 2048 },
      node2: { HostName: "phone", Online: false,
        TailscaleIPs: ["100.64.0.3"] }
    }
  }))
  assert.equal(result.ok, true)
  assert.equal(result.running, true)
  assert.equal(result.selfIp, "100.64.0.1")
  assert.equal(result.fileSharing, true)
  assert.equal(result.onlineCount, 1)
  assert.equal(result.peers.length, 2)
  assert.equal(result.exitNodes[0].HostName, "server")
  assert.deepEqual(result.health, ["key expiring"])
})

test("parses preferences and suggested node", () => {
  const prefs = model.parsePrefs(JSON.stringify({ RouteAll: true,
    CorpDNS: false, ShieldsUp: true, ExitNodeAllowLANAccess: true,
    AdvertiseRoutes: ["0.0.0.0/0", "::/0"], RunSSH: true }))
  assert.deepEqual(prefs, { ok: true, routeAll: true, corpDns: false,
    shieldsUp: true, allowLanAccess: true, advertiseExitNode: true,
    runSsh: true })
  assert.equal(model.parseSuggest("Suggested exit node: relay.example.ts.net.\n"),
    "relay.example.ts.net")
})

test("parses account aliases and selected state", () => {
  const accounts = model.parseAccounts(JSON.stringify([
    { ID: "one", Name: "Personal", Tailnet: "example.com", selected: true },
    { id: "two", nickname: "Work", account: "user@work.example" }
  ]))
  assert.equal(accounts.accounts.length, 2)
  assert.equal(accounts.selectedAccountId, "one")
  assert.equal(accounts.selectedAccountLabel, "Personal")
})

test("deduplicates Mullvad servers into selectable regions", () => {
  const nodes = [
    { Country: "Germany", City: "Frankfurt", HostName: "de1.mullvad.ts.net",
      ExitNode: false },
    { Country: "Germany", City: "Frankfurt", HostName: "de2.mullvad.ts.net",
      ExitNode: true },
    { Country: "Sweden", City: "Gothenburg", HostName: "se1.mullvad.ts.net",
      ExitNode: false }
  ]
  const regions = model.mullvadRegions(nodes)
  assert.equal(regions.length, 2)
  assert.equal(regions[0].HostName, "de2.mullvad.ts.net")
})
