import glob
import json
import os
from os.path import join, islink
import sys
import tarfile
import tempfile
sys.path.insert(0,os.path.expanduser('~/conda/private_conda_recipes/rays-scratch-scripts'))
import binstar_copy

def prefix_files(prefix):
    '''
    Returns a set of all files in prefix.
    '''
    res = set()
    for root, dirs, files in os.walk(prefix):
        for fn in files:
            res.add(join(root, fn)[len(prefix) + 1:])
        for dn in dirs:
            path = join(root, dn)
            if islink(path):
                res.add(path[len(prefix) + 1:])
    res = set(expand_globs(res, prefix))
    return res

def expand_globs(path_list, root_dir):
    files = []
    for path in path_list:
        if not os.path.isabs(path):
            path = os.path.join(root_dir, path)
        if os.path.islink(path):
            files.append(path.replace(root_dir + os.path.sep, ''))
        elif os.path.isdir(path):
            files.extend(os.path.join(root, f).replace(root_dir + os.path.sep, '')
                            for root, _, fs in os.walk(path) for f in fs)
        elif os.path.isfile(path):
            files.append(path.replace(root_dir + os.path.sep, ''))
        else:
            # File compared to the globs use / as separator indenpendently of the os
            glob_files = [f.replace(root_dir + os.path.sep, '')
                          for f in glob(path)]
            files.extend(glob_files)
    files = [f.replace(os.path.sep, '/') for f in files]
    return files

old_dir = '/tmp/r342/old'
new_dir = '/tmp/r342/new'
try:
    os.makedirs(old_dir)
except:
    pass

os.chdir(old_dir)
packages = binstar_copy.get_packages_cli('r', package_name='*', version='*', platform='*', distribution='*r342*')
binstar_copy.download_packages(packages, skip_existing=True)

try:
    os.makedirs(new_dir)
except:
    pass

for filename in glob.iglob(old_dir+'/**/*.tar.bz2', recursive=True):
    print(filename)
    new_filename = filename.replace(old_dir, new_dir)
    if not os.path.exists(new_filename):
        with tempfile.TemporaryDirectory() as td, tarfile.open(filename) as tf:
            os.chdir(td)
            def is_within_directory(directory, target):
                
                abs_directory = os.path.abspath(directory)
                abs_target = os.path.abspath(target)
            
                prefix = os.path.commonprefix([abs_directory, abs_target])
                
                return prefix == abs_directory
            
            def safe_extract(tar, path=".", members=None, *, numeric_owner=False):
            
                for member in tar.getmembers():
                    member_path = os.path.join(path, member.name)
                    if not is_within_directory(path, member_path):
                        raise Exception("Attempted Path Traversal in Tar File")
            
                tar.extractall(path, members, numeric_owner=numeric_owner) 
                
            
            safe_extract(tf)
            # Fixes:
            index_json = json.load(open('info/index.json'))
            print(index_json)
            changed = False
            if 'depends' in index_json:
                if 'r-base' in index_json['depends']:
                    index_json['depends'][index_json['depends'].index('r-base')] = 'r-base >=3.4.2,<3.4.3a0'
                    changed = True
                if 'm2w64-gcc-libs' in index_json['depends']:
                    index_json['depends'].append('msys2-conda-epoch >=20160418')
                    changed = True
            if changed:
                json.dump(index_json, open('info/index.json', 'w'), indent=2)
                try:
                    os.makedirs(os.path.dirname(new_filename))
                except:
                    pass
                with tarfile.open(new_filename, "w:bz2") as t:
                    files = prefix_files(os.getcwd())

                    def order(f):
                        # we don't care about empty files so send them back via 100000
                        fsize = os.stat(f).st_size or 100000
                        # info/* records will be False == 0, others will be 1.
                        info_order = int(os.path.dirname(f) != 'info')
                        return info_order, fsize

                    # add files in order of a) in info directory, b) increasing size so
                    # we can access small manifest or json files without decompressing
                    # possible large binary or data files
                    for f in sorted(files, key=order):
                        t.add(f, f)
                    t.close()
