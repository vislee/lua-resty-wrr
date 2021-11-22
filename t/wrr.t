use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

log_level('debug');

repeat_each(1);
plan tests => repeat_each() * (3 * blocks());

no_long_string();

run_tests();

__DATA__

=== TEST 1: wrr
--- http_config
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
            local rrp = wrr.new(servers)
            if not rrp then
                ngx.print("no live server")
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end

            local peer = rrp:init()
            local s = peer:get()
            ngx.print("server: ", (s and s.addr))
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
