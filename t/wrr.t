use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

log_level('debug');

repeat_each(1);
plan tests => repeat_each() * (3 * blocks());

no_long_string();

run_tests();

__DATA__


=== TEST 1: wrr get
--- http_config
    variables_hash_max_size 2048;
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }

--- config
    location /t {
        content_by_lua_block {
            local wrr = require "resty.wrr"
            local servers = {
                {addr="1.1.1.1:80", weight=1},
                {addr="2.2.2.2:80", weight=4},
            }
            local rrp, err = wrr.new(servers)
            if not rrp then
                ngx.print(err)
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end

            local peer = rrp:init()
            local s = peer:get()
            ngx.print("server: ", (s and s.server.addr))
            peer:free(0)
            ngx.exit(ngx.HTTP_OK)
        }
    }

--- request
GET /t
--- response_body: server: 2.2.2.2:80
--- error_code: 200
--- timeout: 30
--- no_error_log
[error]



=== TEST 2: wrr tries
--- http_config
    variables_hash_max_size 2048;
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }

--- config
    location /t {
        content_by_lua_block {
            local wrr = require "resty.wrr"
            local servers = {
                {addr="1.1.1.1:80", weight=3, max_fails=3,fail_timeout=3,},
                {addr="2.2.2.2:80", weight=2, max_fails=3,fail_timeout=3,},
                {addr="3.3.3.3:80", weight=1, max_fails=3,fail_timeout=3,},
            }
            local rrp = wrr.new(servers)
            if not rrp then
                ngx.print("no live server")
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end

            local peer = rrp:init(2)
            for i = 1, 3 do
                if peer.tries > 0 then
                    local s = peer:get()
                    ngx.print("server: ", (s and s.server.addr), ".")
                    peer:free(wrr.PEER_FAILED)
                else
                    ngx.print(" server: tries 0")
                end
            end
            ngx.exit(ngx.HTTP_OK)
        }
    }

--- request
GET /t
--- response_body: server: 1.1.1.1:80.server: 2.2.2.2:80. server: tries 0
--- error_code: 200
--- timeout: 30
--- no_error_log
[error]



=== TEST 3: max_conns
--- http_config
    variables_hash_max_size 2048;
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }

--- config
    location /t {
        content_by_lua_block {
            local wrr = require "resty.wrr"
            local servers = {
                {addr="1.1.1.1:80", weight=1, max_conns=1,},

            }
            local rrp = wrr.new(servers)
            if not rrp then
                ngx.print("no live server")
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end

            local peer1 = rrp:init(2)
            local s = peer1:get()
            ngx.print("server: ", (s and s.server.addr), ".")

            local peer2 = rrp:init(2)
            s = peer2:get()
            ngx.print("server: ", (s and s.server.addr), ".")

            peer1:free(wrr.PEER_FAILED)

            local peer3 = rrp:init(2)
            s = peer3:get()
            ngx.print("server: ", (s and s.server.addr), ".")

            peer2:free(wrr.PEER_FAILED)
            peer3:free(wrr.PEER_FAILED)

            ngx.exit(ngx.HTTP_OK)
        }
    }

--- request
GET /t
--- response_body: server: 1.1.1.1:80.server: nil.server: 1.1.1.1:80.
--- error_code: 200
--- timeout: 30
--- no_error_log
[error]



=== TEST 4: max_fails
--- http_config
    variables_hash_max_size 2048;
    lua_package_path 'lib/?.lua;;';

    init_by_lua_block {
        require 'luacov.tick'
        jit.off()
    }

--- config
    location /t {
        content_by_lua_block {
            local wrr = require "resty.wrr"
            local servers = {
                {addr="1.1.1.1:80", weight=1, max_fails=2,fail_timeout=1,},

            }
            local rrp = wrr.new(servers)
            if not rrp then
                ngx.print("no live server")
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end

            local peer1 = rrp:init()
            local s = peer1:get()
            ngx.print("server: ", (s and s.server.addr), ".")
            peer1:free(wrr.PEER_FAILED)

            local peer2 = rrp:init()
            local s = peer2:get()
            ngx.print("server: ", (s and s.server.addr), ".")
            peer2:free(wrr.PEER_FAILED)

            local peer3 = rrp:init()
            local s = peer3:get()
            ngx.print("server: ", (s and s.server.addr), ".")
            peer3:free(wrr.PEER_FAILED)

            ngx.sleep(1)
            local peer4 = rrp:init()
            local s = peer4:get()
            ngx.print("server: ", (s and s.server.addr), ".")
            peer3:free()

            ngx.exit(ngx.HTTP_OK)
        }
    }

--- request
GET /t
--- response_body: server: 1.1.1.1:80.server: 1.1.1.1:80.server: nil.server: 1.1.1.1:80.
--- error_code: 200
--- timeout: 30
--- no_error_log
[error]

