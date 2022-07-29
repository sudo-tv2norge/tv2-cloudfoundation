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

import functools
import json
import pathlib
import subprocess

try:
  import click
  import hcl2
  import rich.console
  import yaml
except ImportError as e:
  print('Missing dependencies (hint: pip install -r requirements.txt')
  raise

# https://apps.timwhitlock.info/emoji/tables/unicode
EMOJI_FILE = '\N{dvd}'
EMOJI_KO = '\N{cross mark}'
EMOJI_OK = '\N{white heavy check mark}'
JUSTIFY = 50

STAGE_TFVARS = ('{}.auto.tfvars.json', '{}.auto.tfvars', 'terraform.tfvars')


class Error(Exception):
  pass


def get_config(stage_dir='.'):
  'Read and parse stage attributes from YAML file.'
  config = pathlib.Path(stage_dir) / '.fast-install.yaml'
  if not config.exists():
    raise Error('Stage configuration missing.')
  try:
    with config.open() as fp:
      data = yaml.load(fp, Loader=yaml.Loader)['stage']
  except (IOError, OSError) as e:
    raise Error(f'Cannot open \'{config}\': {e.args[0]}')
  except KeyError as e:
    raise Error(f'Incorrect stage attributes format: {e.args[0]}')
  if not all(data.get(k) for k in ('id', 'name', 'description')):
    raise Error(f'Incorrect stage attributes format: missing or empty field.')
  return data


def get_interface_files(stage_id, required_stages, stage_dir='.'):
  'Return a boolean indicating if all FAST interface files are present.'
  stage_path = pathlib.Path(stage_dir)
  interface_files = [stage_path / f'{stage_id}-providers.tf']
  if stage_id != '00-bootstrap':
    interface_files += [stage_path / '00-globals.auto.tfvars.json']
  interface_files += [
      stage_path / f'{s}.auto.tfvars.json' for s in required_stages
  ]
  return {f.name: f.exists() for f in interface_files}


def get_sibling_stage_dir(stage_dir, sibling_id):
  'Return the path of a sibling stage.'
  try:
    stage_path = pathlib.Path(stage_dir).resolve(strict=True)
  except FileNotFoundError:
    return
  name, env = sibling_id, None
  root_path = stage_path / '..'
  if not stage_path.name.startswith('0'):
    root_path = root_path / '..'
  if sibling_id.startswith('03'):
    name, _, env = sibling_id.rpartition('-')
  sibling_path = root_path / name
  if env:
    sibling_path = sibling_path / env
  return str(sibling_path) if sibling_path.exists() else None


def try_stage_outputs(stage_id='00-bootstrap'):
  return


def parse_tfvars(fname):
  'Read and parse tfvars file and return its data.'
  try:
    with open(fname) as fp:
      return json.load(fp) if fname.endswith('.json') else hcl2.load(fp)
  except (IOError, OSError) as e:
    raise Error(f'Cannot open \'{fname}\': {e.args[0]}')


def _print(s, emoji=EMOJI_FILE, justify=JUSTIFY, end=''):
  'Print left justified string prefixed by emoji.'
  print(f'{emoji} {s.ljust(justify)}', end='')


def _run_cmd(cmd, cwd=None, return_none=False):
  'Run command.'
  cmd = cmd.split()
  error = None
  try:
    result = subprocess.run(cmd, capture_output=True, cwd=cwd)
  except FileNotFoundError as e:
    error = e.args[0]
    text = (
        f'Missing dependency: the {cmd[0]} executable needs to be installed '
        ' and in a system path.')
  else:
    if result.returncode != 0:
      error = result.stderr.decode('utf-8').strip()
      text = f'Error running {cmd[0]} command: {error}'
  if error:
    if return_none:
      return
    raise Error(text, cmd, error)
  out = result.stdout.decode('utf-8').strip()
  return out


@click.command()
@click.argument('stage_dir', default='.',
                type=click.Path(exists=True, file_okay=False, dir_okay=True,
                                resolve_path=True))
def main(stage_dir='.'):
  console = rich.console.Console()
  try:
    _print('reading YAML configuration')
    attrs = get_config(stage_dir)
    print(EMOJI_OK)
    _print('checking FAST interface files')
    interface_files = get_interface_files(attrs['id'], attrs['requires'],
                                          stage_dir)
    if all(v for v in interface_files.values()):
      print(EMOJI_OK)
    else:
      print(EMOJI_KO)
      if attrs['id'] != '00-bootstrap':
        bootstrap_dir = get_sibling_stage_dir(stage_dir, '00-bootstrap')
        _print('looking for bootstrap stage')
        if not bootstrap_dir:
          print(EMOJI_KO)
        else:
          print(EMOJI_OK)
          _print('trying bootstrap stage outputs')
          bootstrap_output = _run_cmd('terraform output -json',
                                      cwd=bootstrap_dir, return_none=True)
          if not bootstrap_output:
            print(EMOJI_KO)
          else:
            print(EMOJI_OK)
            print(bootstrap_output)
      # try to find stage 0 and get its outputs
      # if it does not succeed, prompt for GCS bucket or single stage setup
      # if we have a GCS bucket, link files
      pass
  except Error as e:
    print(EMOJI_KO)
    console.print('\n[bold red]An error has occurred.[/bold red]')
    raise SystemExit(e.args[0])
  print(attrs)
  print(interface_files)


if __name__ == '__main__':
  main()