#!/usr/bin/env python

'''
usage: ./parse_repo.py -v 9.6 -u https://yum.postgresql.org/9.6/redhat/rhel-7-x86_64/ -d centos
output: pgdg-centos96-9.6-3.noarch.rpm
'''

import sys
import logging
import urllib2
import re
import argparse

logfile = '/tmp/parse_repo.log'

#______________________________________
def cli_options():
  parser = argparse.ArgumentParser(description='Onedata connection script')
  parser.add_argument('-u', '--url', dest='url', help='Url')
  parser.add_argument('-d', '--distribution', dest='dist', help='Ditribution')
  parser.add_argument('-v', '--version', dest='pg_version', help='Postgresql version')
  return parser.parse_args()

#______________________________________
def parse_repo():

  options = cli_options()

  logging.basicConfig(filename=logfile,level=logging.DEBUG)
  logging.debug('>>> Parsing Postgresql PGDG repository.')

  try:
    response = urllib2.urlopen(options.url)
  except (urllib2.HTTPError):
    logging.debug('[Warning] %s not found.', options.url)
    raise

  # ansible code
  # pgdg-{{ postgresql_pgdg_dist }}{{ postgresql_version_terse }}-{{ postgresql_version }}-{{ postgresql_pgdg_release }}.noarch.rpm"

  pg_version_terse = options.pg_version.replace('.','')

  parse = 'href=[\'"](pgdg-%s%s-%s-[\d+].noarch.rpm)[\'"]' % (options.dist, pg_version_terse, options.pg_version)
  find = re.findall(parse, response.read(), flags=re.I)
  
  try:
    assert find
  except AssertionError:
    logging.debug('[Error] No postgresql %s version %s at %s' % (options.dist, options.pg_version, options.url))
    raise
  
  logging.debug('Postgresql %s version: %s' % (options.dist, find[0]))
  print find[0]

#______________________________________
if __name__ == '__main__':
  parse_repo()
