#! /usr/bin/env python3
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import pathlib

try:
  import hcl2
except ImportError as e:
  print('Missing dependencies (hint: pip install -r requirements.txt')
  raise

_STAGE_TFVARS = ('{}.auto.tfvars.json', '{}.auto.tfvars', 'terraform.tfvars')


class Error(Exception):
  pass


def _check_stage(dirname):
  stage_dir = pathlib.Path(dirname).resolve(strict=True)
  stage_name = '-'.join(stage_dir.name.split('-')[:2])
  stage_tfvars = [
      p.name for p in [stage_dir / p.format(stage_name)
                       for p in _STAGE_TFVARS] if p.exists()
  ]
  print(stage_tfvars)


def _parse_tfvars(fname):
  try:
    with open(fname) as fp:
      return json.load(fp) if fname.endswith('.json') else hcl2.load(fp)
  except (IOError, OSError) as e:
    raise Error(f'Cannot open \'{fname}\': {e.args[0]}')


if __name__ == '__main__':
  _check_stage('.')