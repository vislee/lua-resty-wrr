# lua-resty-wrr
weight round robin for Openresty. Similar to `ngx_http/stream_upstream_round_robin` module.


Table of Contents
=================

* [Synopsis](#synopsis)
* [Methods](#methods)
    * [new](#new)
    * [init](#init)
    * [get](#get)
    * [free](#free)
* [Author](#author)
* [Copyright and License](#copyright-and-license)


Synopsis
========

```nginx
http {

    ...

    init_by_lua_block {
        local wrr = require "resty.wrr"
        local servers = {
            {addr="192.168.0.1:80",weight=1,max_fails=5,fail_timeout=3,max_conns=1000,},
            {addr="192.168.0.2:80",weight=2,max_fails=5,fail_timeout=3,max_conns=2000,},
        }
        rrp = wrr.new(servers)
    }

    server {
        listen 8080;

        location / {
            access_by_lua_block {
                local peer = rrp:init()
                local s = peer:get()
                ...
                peer:free()
            }

            proxy_pass ups;
        }
    }
}
```

[Back to TOC](#table-of-contents)


Methods
=======

new
---
`syntax: rrp = wrr.new(servers)`

Creates a wrr object by `servers`. the failures, returns `nil` and error.


init
----
`syntax: peer = rrp:init(tries?)`

Creates a object for request. the `tries` is max retry times.

`peer.tries`: remaining retry times.


get
---
`syntax: server = peer:get()`

Pick a upstream server in peer object. No server is available, returns `nil`.


free
----
`syntax: peer:free(state?)`

Free the pick server and report a health failure, the `state` is `wrr.PEER_FAILED`(failed) or 0(OK).


[Back to TOC](#table-of-contents)



Author
======

wenqiang li(vislee)

[Back to TOC](#table-of-contents)



Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2021-, by vislee.

All rights reserved.

[Back to TOC](#table-of-contents)

