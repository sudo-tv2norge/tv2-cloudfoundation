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


def try_stage_outputs(stage_id='00-bootstrap'):
  return


def parse_tfvars(fname):
  'Read and parse tfvars file and return its data.'
  try:
    with open(fname) as fp:
      return json.load(fp) if fname.endswith('.json') else hcl2.load(fp)
  except (IOError, OSError) as e:
    raise Error(f'Cannot open \'{fname}\': {e.args[0]}')


def _run_cmd(cmd):
  cmd = cmd.split()
  try:
    result = subprocess.run(cmd, capture_output=True)
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
    raise Error(text, cmd, error)
  out = result.stdout.decode('utf-8').strip()
  return out


def _run_func(s, func, emoji=EMOJI_FILE, justify=48):
  print(f'{emoji} {s.ljust(justify)}', end='')
  result = func()
  print(EMOJI_OK)
  return result


@click.command()
@click.argument('stage_dir', default='.',
                type=click.Path(exists=True, file_okay=False, dir_okay=True,
                                resolve_path=True))
def main(stage_dir='.'):
  console = rich.console.Console()
  try:
    attrs = _run_func('reading YAML configuration',
                      functools.partial(get_config, stage_dir))
    interface_files = _run_func(
        'checking FAST interface files',
        functools.partial(get_interface_files, attrs['id'], attrs['requires'],
                          stage_dir))
    if not all(v for v in interface_files.values()):
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