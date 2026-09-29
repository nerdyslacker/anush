// Data normalization for the Tailscale widget. Kept free of QML state so the
// CLI's JSON can be tested independently.

function cleanDnsName(value) {
    var name = String(value || "")
    return name.charAt(name.length - 1) === "." ? name.slice(0, -1) : name
}

function shortName(value) {
    var name = cleanDnsName(value)
    return name === "" ? "" : name.split(".")[0]
}

function displayName(host, dns) {
    var value = String(host || "")
    return value !== "" && value.toLowerCase() !== "localhost"
        ? value : shortName(dns) || value || "Unknown"
}

function ipv4(values) {
    var result = []
    values = values && typeof values.length === "number" ? values : []
    for (var i = 0; i < values.length; ++i) {
        var value = String(values[i] || "")
        if (/^100\./.test(value)) result.push(value)
    }
    return result
}

function isMullvadName(value) {
    return /\.mullvad\.ts\.net\.?$/i.test(String(value || ""))
}

function hasFileSharing(self) {
    var capability = "https://tailscale.com/cap/file-sharing"
    var map = self && self.CapMap
    if (map && map[capability] !== undefined) return true
    var values = self && self.Capabilities || []
    for (var i = 0; i < values.length; ++i)
        if (String(values[i]) === capability) return true
    return false
}

function peer(id, raw) {
    raw = raw || {}
    var dns = cleanDnsName(raw.DNSName)
    return {
        id: String(id || ""),
        HostName: displayName(raw.HostName, dns),
        DNSName: dns,
        UserID: String(raw.UserID || ""),
        TailscaleIPs: ipv4(raw.TailscaleIPs || []),
        Online: raw.Online === true,
        Active: raw.Active === true,
        OS: String(raw.OS || ""),
        Tags: raw.Tags || [],
        ExitNodeOption: raw.ExitNodeOption === true,
        ExitNode: raw.ExitNode === true,
        TaildropTarget: typeof raw.TaildropTarget === "number"
            ? raw.TaildropTarget : 0,
        SSH: !!raw.SSH_HostKeys,
        RxBytes: Number(raw.RxBytes || 0),
        TxBytes: Number(raw.TxBytes || 0),
        LastSeen: String(raw.LastSeen || ""),
        Mullvad: isMullvadName(dns) || isMullvadName(raw.HostName)
    }
}

function parseStatus(text) {
    text = String(text || "").trim()
    if (text === "") return { ok: false, message: "No status received" }
    try {
        var data = JSON.parse(text)
        var self = data.Self || {}
        var selfIps = ipv4(self.TailscaleIPs || data.TailscaleIPs || [])
        var peers = []
        var exitNodes = []
        var activeMullvadExit = ""
        var onlineCount = 0
        var rawPeers = data.Peer || {}
        for (var id in rawPeers) {
            var item = peer(id, rawPeers[id])
            if (item.Mullvad) {
                if (item.ExitNode) activeMullvadExit = item.HostName
                continue
            }
            peers.push(item)
            if (item.Online) {
                ++onlineCount
                if (item.ExitNodeOption) exitNodes.push(item)
            }
        }
        peers.sort(function(a, b) {
            if (a.Online !== b.Online) return a.Online ? -1 : 1
            return a.HostName.localeCompare(b.HostName)
        })
        exitNodes.sort(function(a, b) {
            return a.HostName.localeCompare(b.HostName)
        })
        var health = []
        var rawHealth = data.Health || []
        for (var h = 0; h < rawHealth.length; ++h) {
            var warning = String(rawHealth[h] || "").trim()
            if (warning !== "") health.push(warning)
        }
        var backend = String(data.BackendState || "Unknown")
        return {
            ok: true,
            backendState: backend,
            running: backend === "Running",
            needsLogin: backend === "NeedsLogin",
            authUrl: String(data.AuthURL || ""),
            selfName: displayName(self.HostName, self.DNSName),
            selfDnsName: cleanDnsName(self.DNSName),
            selfIp: selfIps.length ? selfIps[0] : "",
            selfUserId: String(self.UserID || ""),
            fileSharing: hasFileSharing(self),
            peers: peers,
            exitNodes: exitNodes,
            activeMullvadExit: activeMullvadExit,
            onlineCount: onlineCount,
            health: health
        }
    } catch (error) {
        return { ok: false, message: "Tailscale returned invalid status data" }
    }
}

function column(line, start, end) {
    if (start < 0 || start >= line.length) return ""
    return line.substring(start, end < 0 ? line.length : end).trim()
}

function parseExitNodes(text) {
    var lines = String(text || "").split(/\r?\n/)
    var headerIndex = -1
    var header = ""
    for (var i = 0; i < lines.length; ++i) {
        if (/^\s*IP\s+HOSTNAME\s+COUNTRY\s+CITY\s+STATUS\s*$/.test(lines[i])) {
            headerIndex = i
            header = lines[i]
            break
        }
    }
    if (headerIndex < 0) return []
    var ipAt = header.indexOf("IP")
    var hostAt = header.indexOf("HOSTNAME")
    var countryAt = header.indexOf("COUNTRY")
    var cityAt = header.indexOf("CITY")
    var statusAt = header.indexOf("STATUS")
    var result = []
    for (var row = headerIndex + 1; row < lines.length; ++row) {
        var line = lines[row]
        var host = column(line, hostAt, countryAt)
        if (!isMullvadName(host)) continue
        var country = column(line, countryAt, cityAt)
        var city = column(line, cityAt, statusAt)
        var status = column(line, statusAt, -1)
        result.push({
            id: "mullvad:" + host,
            HostName: host,
            DNSName: host,
            TailscaleIPs: [column(line, ipAt, hostAt)],
            Country: country,
            City: city,
            DisplayName: (city && city !== "Any" ? city + ", " : "") + country,
            ExitNode: status !== "" && status !== "-",
            ExitNodeOption: true,
            Online: true,
            Mullvad: true,
            OS: "mullvad"
        })
    }
    result.sort(function(a, b) {
        var country = a.Country.localeCompare(b.Country)
        return country || a.DisplayName.localeCompare(b.DisplayName)
    })
    return result
}

function mullvadRegions(nodes) {
    var byRegion = {}
    for (var i = 0; i < nodes.length; ++i) {
        var item = nodes[i]
        if (!item.City || item.City === "Any" || !item.Country) continue
        var key = item.Country + "\n" + item.City
        if (!byRegion[key] || item.ExitNode) byRegion[key] = item
    }
    var result = []
    for (var name in byRegion) result.push(byRegion[name])
    result.sort(function(a, b) {
        var country = a.Country.localeCompare(b.Country)
        return country || a.City.localeCompare(b.City)
    })
    return result
}

function parsePrefs(text) {
    try {
        var data = JSON.parse(String(text || ""))
        var routes = data.AdvertiseRoutes || []
        var advertisesV4 = routes.indexOf("0.0.0.0/0") >= 0
        var advertisesV6 = routes.indexOf("::/0") >= 0
        return { ok: true, routeAll: data.RouteAll === true,
            corpDns: data.CorpDNS === true, shieldsUp: data.ShieldsUp === true,
            allowLanAccess: data.ExitNodeAllowLANAccess === true,
            advertiseExitNode: advertisesV4 || advertisesV6,
            runSsh: data.RunSSH === true }
    } catch (error) { return { ok: false } }
}

function accountLabel(account) {
    return String(account.nickname || account.tailnet || account.account
        || account.id || "Unknown account")
}

function parseAccounts(text) {
    try {
        var raw = JSON.parse(String(text || ""))
        var accounts = []
        var selected = null
        for (var i = 0; i < raw.length; ++i) {
            var source = raw[i] || {}
            var item = { id: String(source.id || source.ID || ""),
                nickname: String(source.nickname || source.Nickname
                    || source.name || source.Name || ""),
                tailnet: String(source.tailnet || source.Tailnet || ""),
                account: String(source.account || source.Account
                    || source.loginName || source.LoginName || ""),
                selected: source.selected === true || source.Selected === true
                    || source.Current === true || source.current === true }
            if (item.id !== "") accounts.push(item)
            if (item.selected) selected = item
        }
        return { accounts: accounts,
            selectedAccountId: selected ? selected.id : "",
            selectedAccountLabel: selected ? accountLabel(selected) : "" }
    } catch (error) {
        return { accounts: [], selectedAccountId: "", selectedAccountLabel: "" }
    }
}

function parseSuggest(text) {
    var match = String(text || "").match(/Suggested exit node:\s*(\S+)/)
    return match ? cleanDnsName(match[1]) : ""
}

function filterPeers(peers, query) {
    var needle = String(query || "").trim().toLowerCase()
    if (needle === "") return peers
    return peers.filter(function(item) {
        return (item.HostName + " " + item.DNSName + " "
            + item.TailscaleIPs.join(" ")).toLowerCase().indexOf(needle) >= 0
    })
}

function canTaildrop(peer, selfUserId) {
    if (peer.TaildropTarget) return peer.TaildropTarget === 1
    return peer.UserID !== "" && peer.UserID === String(selfUserId || "")
}

function fmtBytes(number) {
    var value = Number(number) || 0
    if (value < 1024) return value + " B"
    var units = ["KiB", "MiB", "GiB", "TiB"]
    var unit = -1
    do { value /= 1024; ++unit } while (value >= 1024 && unit < 3)
    return (value >= 10 ? Math.round(value) : Math.round(value * 10) / 10)
        + " " + units[unit]
}

function fmtLastSeen(value) {
    var text = String(value || "")
    if (text === "" || text.indexOf("0001-") === 0) return "never"
    var time = Date.parse(text)
    if (isNaN(time)) return "never"
    var minutes = Math.max(0, Math.floor((Date.now() - time) / 60000))
    if (minutes < 1) return "now"
    if (minutes < 60) return minutes + "m ago"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h ago"
    var days = Math.floor(hours / 24)
    return days < 30 ? days + "d ago" : text.slice(0, 10)
}

function osIcon(os) {
    var value = String(os || "").toLowerCase()
    if (value === "linux") return "󰌽"
    if (value === "windows") return "󰍲"
    if (value === "android") return "󰀲"
    if (value === "macos" || value === "ios") return "󰀵"
    return "󰟀"
}

if (typeof module !== "undefined") module.exports = {
    cleanDnsName: cleanDnsName, displayName: displayName, ipv4: ipv4,
    parseStatus: parseStatus, parseExitNodes: parseExitNodes,
    mullvadRegions: mullvadRegions, parsePrefs: parsePrefs,
    parseAccounts: parseAccounts, parseSuggest: parseSuggest,
    filterPeers: filterPeers, canTaildrop: canTaildrop,
    fmtBytes: fmtBytes, fmtLastSeen: fmtLastSeen, osIcon: osIcon
}
