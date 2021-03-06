#!/usr/bin/env python

import sys
sys.path.insert(1,'/home/galaxy/galaxy')
sys.path.insert(1,'/home/galaxy/galaxy')

from scripts.db_shell import *
from galaxy.util.bunch import Bunch
from galaxy.security import GalaxyRBACAgent
from sqlalchemy.orm import sessionmaker
from sqlalchemy import *
import argparse
bunch = Bunch( **globals() )
engine = create_engine('postgresql://galaxy:galaxy@localhost:5432/galaxy')
bunch.session = sessionmaker(bind=engine)
# For backward compatibility with "model.context.current"
bunch.context = sessionmaker(bind=engine)

security_agent = GalaxyRBACAgent( bunch )
security_agent.sa_session = sa_session

#______________________________________
def cli_options():
  parser = argparse.ArgumentParser(description='Delete galaxy users')
  parser.add_argument('-u', '--user',  dest='user', help='User to delete')
  parser.add_argument('-c', '--config-file', dest='config_file', help='Galaxy ini file')
  return parser.parse_args()

#______________________________________
def delete_user(email):

  query = sa_session.query( User ).filter_by( email=email )

  if query.count() > 0:
    user = query.first()
    sa_session.delete(user)
    sa_session.flush()
  else:
    print 'No user %s found' % email
    #raise Exception('No user %s found' % email)

#______________________________________
def delete_galaxy_user():

  options = cli_options()

  delete_user(options.user)

if __name__ == "__main__":
   delete_galaxy_user()
