#!/usr/bin/python
#
# usage: python testRedis.py 40.76.5.86
#
import redis
import sys

r = redis.StrictRedis(host=sys.argv[1], port=6379, db=0)

print("set 'foo = bar'")
ret = r.set('foo', 'bar')
print(ret)

print("get 'foo'")
ret = r.get('foo')
print(ret)
