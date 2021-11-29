-- Copyright (C) vislee

-- local cjson = require "cjson.safe"
-- local json_encode  = cjson.encode
local ngx_now = ngx.now
local math_floor = math.floor
local PEER_FAILED = 1
local _M = {PEER_FAILED = PEER_FAILED}
local mt = { __index = _M }

--[[
servers = {
{
  addr = "192.168.0.1:80",
  weight = 1,
  max_conns = 0,
  max_fails = 0,
  fail_timeout = 0,
},
{
  addr = "192.168.0.2:80",
  weight = 1,
  max_conns = 0,
  max_fails = 0,
  fail_timeout = 0,
}
}
-- ]]
function _M.new(servers)
    if not servers or type(servers) ~= "table" then
        return nil, "Invalid servers"
    end

    local tries = 0
    local peers = {}
    for n, s in ipairs(servers) do
        local peer = {}
        peer["server"] = s
        peer["weight"] = s["weight"] or 1
        peer["effective_weight"] = s["weight"]
        peer["current_weight"] = 0
        peer["max_conns"] = s["max_conns"] or 0
        peer["max_fails"] = s["max_fails"] or 0
        peer["fail_timeout"] = s["fail_timeout"] or 0
        peer["conns"] = 0
        peer["accessed"] = 0
        peer["fails"] = 0
        peer["checked"] = 0

        peers[n] = peer
        tries = tries + 1
    end

    return setmetatable({peers = peers, tries = tries}, mt)
end


function _M.init(self, tries)
    local t = tries or self.tries
    if t > self.tries then
        t = self.tries
    end

    return setmetatable({peers = self.peers, tries = t, tried = {}}, mt)
end


-- function _M.debug(self)
--     return json_encode(self.peers)
-- end


function _M.get(self)
    local best
    local p = 0
    local total = 0
    local now = ngx_now()

    for n, peer in ipairs(self.peers) do
        if self.tried and self.tried[n] then
            goto continue
        end

        if peer.max_fails > 0 and peer.fails >= peer.max_fails and now - peer.checked <= peer.fail_timeout then
            goto continue
        end

        if peer.max_conns > 0 and peer.conns >= peer.max_conns then
            goto continue
        end

        peer.current_weight = peer.current_weight + peer.effective_weight
        total = total + peer.effective_weight;

        if peer.effective_weight < peer.weight then
            peer.effective_weight = peer.effective_weight + 1
        end

        if best == nil or peer.current_weight > best.current_weight then
            best = peer
            p = n
        end

::continue::
    end

    if best == nil then
        return best
    end

    if self.tried and type(self.tried) == "table" then
        self.tried[p] = true
    end

    best.current_weight = best.current_weight - total
    best.conns = best.conns + 1
    self.current = best

    if now - best.checked > best.fail_timeout then
        best.checked = now
    end

    return best
end


function _M.free(self, state)
    local peer = self.current

    if not peer then
        return
    end

    if state and state == PEER_FAILED then
        local now = ngx_now()
        peer.fails = peer.fails + 1
        peer.accessed = now
        peer.checked = now

        if peer.max_fails > 0 then
            peer.effective_weight = peer.effective_weight - math_floor(peer.weight/peer.max_fails)

            if peer.fails >= peer.max_fails then
                ngx.log(ngx.WARN, "wrr server temporarily disabled");
            end
        end

        if peer.effective_weight < 0 then
            peer.effective_weight = 0
        end
    else
        if peer.accessed < peer.checked then
            peer.fails = 0
        end
    end

    peer.conns = peer.conns - 1

    if self.tries > 0 then
        self.tries = self.tries - 1
    end
end


return _M
