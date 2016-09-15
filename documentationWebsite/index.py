#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-

# region header
'''
    This script is indented to use as "post-commit" hook for any git \
    repository with a page branch.
'''

# # python3.5
# # pass
from __future__ import absolute_import, division, print_function, \
    unicode_literals
# #

'''
    For conventions see "boostNode/__init__.py" on \
    https://github.com/thaibault/boostNode
'''

__author__ = 'Torben Sickert'
__copyright__ = 'see boostNode/__init__.py'
__credits__ = 'Torben Sickert',
__license__ = 'see boostNode/__init__.py'
__maintainer__ = 'Torben Sickert'
__maintainer_email__ = 'info["~at~"]torben.website'
__status__ = 'stable'
__version__ = '1.0'

from base64 import b64encode as base64_encode
# # python3.5
# # import builtins
import __builtin__ as builtins
# #
import inspect
import json
import logging
try:
    import markdown
except builtins.ImportError:
    markdown = None
import os
import re as regularExpression
import sys
from tempfile import mkdtemp as make_temporary_directory
from tempfile import mkstemp as make_secure_temporary_file
import zipfile

sys.path.append(os.environ['ILU_PUBLIC_REPOSITORY_PATH'])

from boostNode import __get_all_modules__
# # python3.5 from boostNode.aspect.signature import add_check as add_signature_check
pass
from boostNode.extension.file import Handler as FileHandler
from boostNode.extension.native import Dictionary, Module, String
from boostNode.extension.system import CommandLine, Platform
from boostNode.paradigm.aspectOrientation import JointPoint
from boostNode.runnable.macro import Replace as ReplaceMacro
from boostNode.runnable.template import Parser as TemplateParser


# # python3.5
# # if sys.flags.optimize:
# #     '''
# #         Add signature checking for all functions and methods with joint \
# #         points in this module.
# #     '''
# #     add_signature_check(point_cut='%s\..+' % Module.get_name(
# #         frame=inspect.currentframe()))
pass
# #
# endregion
# region globals
## region locations
DOCUMENTATION_BUILD_PATH = 'build/'
DATA_PATH = 'data/'
API_DOCUMENTATION_PATH = 'apiDocumentation/', '/api/'
API_DOCUMENTATION_PATH_SUFFIX = '{name}/{version}/'
DISTRIBUTION_BUNDLE_FILE_PATH = '%sdistributionBundle.zip' % DATA_PATH
DISTRIBUTION_BUNDLE_DIRECTORY_PATH = '%sdistributionBundle' % DATA_PATH
## endregion
BUILD_DOCUMENTATION_PAGE_COMMAND = [
    '/usr/bin/env', 'npm', 'run', 'build',
    '{{' +
    'module:{{preprocessor:{{pug:{{locals:{serializedParameter}}}}}}},' +
    # NOTE: We habe to disable offline features since the domains cache is
    # already in use
    'offline:null' +
    '}}'
]
CONTENT = ''
DOCUMENTATION_REPOSITORY = 'git@github.com:"thaibault/documentationWebsite"'
MARKDOWN_EXTENSIONS = (
    'toc', 'codehilite', 'extra', 'headerid', 'meta', 'sane_lists', 'wikilinks'
)  # , 'nl2br')
PROJECT_PAGE_COMMIT_MESSAGE = 'Update project homepage content.'
SCOPE = {'name': '__dummy__', 'version': '1.0.0'}
# endregion


# region functions
@JointPoint
# # python3.5 def main() -> None:
def main():
    '''Entry point for this script.'''
    global API_DOCUMENTATION_PATH_SUFFIX, CONTENT, SCOPE
    if markdown is None:
        __logger__.critical(
            "You haven't install a suitable markdown version. Documentation "
            "couldn't be updated.")
        return None
    CommandLine.argument_parser(module_name=__name__)
    if '* master' in Platform.run('/usr/bin/env git branch')[
        'standard_output'
    ] and 'gh-pages' in Platform.run('/usr/bin/env git branch --all')[
        'standard_output'
    ]:
        package_file = FileHandler('package.json')
        if package_file.is_file():
            SCOPE = json.loads(package_file.content)
        API_DOCUMENTATION_PATH_SUFFIX = API_DOCUMENTATION_PATH_SUFFIX.format(
            **SCOPE)
        temporary_documentation_folder = FileHandler(
            location=DOCUMENTATION_REPOSITORY[DOCUMENTATION_REPOSITORY.find(
                '/'
            ) + 1:-1])
        if temporary_documentation_folder:
            temporary_documentation_folder.remove_deep()
        __logger__.info('Compile all readme markdown files to html5.')
        FileHandler().iterate_directory(function=add_readme, recursive=True)
        CONTENT = markdown.markdown(
            CONTENT, output='html5',
            extensions=builtins.list(MARKDOWN_EXTENSIONS))
        distribution_bundle_file = create_distribution_bundle_file()
        if distribution_bundle_file is not None:
            data_location = FileHandler(location=DATA_PATH)
            data_location.make_directories()
            distribution_bundle_file.directory = data_location
        has_api_documentation = SCOPE['scripts'].get('document', False)
        if has_api_documentation:
            has_api_documentation = Platform.run(
                '/usr/bin/env npm run document', error=False, log=True
            )['return_code'] == 0
        if Platform.run(
            ('/usr/bin/env git checkout gh-pages', '/usr/bin/env git pull'),
            error=False, log=True
        )['return_code'][0] == 0:
            existing_api_documentation_directory = FileHandler(location='.%s' %
                API_DOCUMENTATION_PATH[1])
            if existing_api_documentation_directory.is_directory():
                existing_api_documentation_directory.remove_deep()
            FileHandler(location=API_DOCUMENTATION_PATH[0]).path = \
                existing_api_documentation_directory
            local_documentation_website_location = FileHandler(
                location='../%s' % temporary_documentation_folder.name)
            if local_documentation_website_location.is_directory():
                temporary_documentation_folder.make_directories()
                local_documentation_website_location.iterate_directory(
                    function=copy_repository_file, recursive=True,
                    source=local_documentation_website_location,
                    target=temporary_documentation_folder)
                node_modules_directory = FileHandler(location='%s%s' % (
                    local_documentation_website_location.path, 'node_modules'))
                if node_modules_directory.is_directory():
                    '''
                        NOTE: Symlinking doesn't work since some node modules
                        need the right absolute location to work.

                        node_modules_directory.make_symbolic_link(
                            target='%s%s' % (
                                temporary_documentation_folder, 'node_modules')
                        )
                        return_code = 0

                        NOTE: Coping complete "node_modules" folder takes to
                        long.

                        node_modules_directory.copy(target='%s%s' % (
                            temporary_documentation_folder, 'node_modules'))
                        return_code = 0
                    '''
                    temporary_documentation_node_modules_directory = \
                        FileHandler('%snode_modules' %
                            temporary_documentation_folder.path)
                    temporary_documentation_node_modules_directory\
                        .make_directory(right=777)
                    return_code = Platform.run(
                        "/usr/bin/env sudo mount --bind '%s' '%s'" % (
                            node_modules_directory.path,
                            temporary_documentation_node_modules_directory.path
                        ), native_shell=True, error=False, log=True
                    )['return_code']
                else:
                    return_code = Platform.run(
                        '/usr/bin/env npm update', native_shell=True,
                        error=False, log=True
                    )['return_code']
                if return_code == 0:
                    current_working_directory_backup = FileHandler()
                    temporary_documentation_folder.change_working_directory()
                    return_code = Platform.run(
                        '/usr/bin/env npm run clear', native_shell=True,
                        error=False, log=True
                    )['return_code']
                    current_working_directory_backup.change_working_directory()
            else:
                return_code = Platform.run((
                    'unset GIT_WORK_TREE; /usr/bin/env git clone %s;'
                    'npm update'
                ) % DOCUMENTATION_REPOSITORY, native_shell=True, error=False,
                log=True)['return_code']
            if return_code == 0:
                generate_new_documentation_page(
                    temporary_documentation_folder,
                    distribution_bundle_file, has_api_documentation,
                    temporary_documentation_node_modules_directory)


@JointPoint
# # python3.5
# # def generate_api_documentation(
# #     current_working_directory: FileHandler
# # ) -> None:
def generate_python_api_documentation(current_working_directory):
# #
    '''Generates the given language type api documentation website.'''
    if FileHandler('documentation').is_directory():
        index_file = FileHandler('documentation/source/index.rst')
        modules_to_document = '\ninit'
        FileHandler(
            location='%sinit.rst' % index_file.directory.path
        ).content = (
            (79 * '=') + '\n{name}\n' + (79 * '=') + '\n\n.. automodule::' +
            ' {name}\n    :members:'
        ).format(name=current_working_directory.name)
        for file in FileHandler():
            if Module.is_package(file.path):
                modules_to_document += '\n    %s' % file.name
                FileHandler(location='%s%s.rst' % (
                    index_file.directory.path, file.name
                )).content = (
                    (79 * '=') + '\n{name}.{package}\n' +
                    (79 * '=') + '\n\n.. automodule:: {name}.{package}\n'
                    '    :members:'
                ).format(
                    name=current_working_directory.name, package=file.name)
                for module in __get_all_modules__(file.path):
                    modules_to_document += '\n    %s.%s' % (file.name, module)
                    FileHandler(location='%s%s.%s.rst' % (
                        index_file.directory.path, file.name, module
                    )).content = (
                        (79 * '=') + '\n{name}.{package}.{module}\n' +
                        (79 * '=') + '\n\n.. automodule:: {name}.{package}.'
                        '{module}\n    :members:'
                    ).format(
                        name=current_working_directory.name,
                        package=file.name, module=module)
        index_file.content = regularExpression.compile(
            '\n    ([a-z][a-zA-Z]+\n)+$', regularExpression.DOTALL
        ).sub(modules_to_document, index_file.content)
        Platform.run('/usr/bin/env git add --all', error=False, log=True)
        FileHandler('documentation').change_working_directory()
        makefile = FileHandler('Makefile')
# # python3.5         FileHandler('MakefilePython3').copy(makefile)
        FileHandler('MakefilePython2').copy(makefile)
        Platform.run(
            command='make html', native_shell=True, error=False, log=True)
        makefile.remove_file()
        FileHandler('build/html').path = '../tempAPI'
        FileHandler('build').remove_deep()


@JointPoint
# # python3.5
# # def generate_new_documentation_page(
# #     temporary_documentation_folder: FileHandler,
# #     distribution_bundle_file: (FileHandler, builtins.type(None)),
# #     has_api_documentation: builtins.bool,
# #     temporary_documentation_node_modules_directory: FileHandler
# # ) -> None:
def generate_new_documentation_page(
    temporary_documentation_folder, distribution_bundle_file,
    has_api_documentation, temporary_documentation_node_modules_directory
):
# #
    '''
        Renders a new index.html file and copies new assets to generate a new \
        documentation homepage.
    '''
    global BUILD_DOCUMENTATION_PAGE_COMMAND
    __logger__.info('Update documentation design.')
    if distribution_bundle_file:
        new_distribution_bundle_file = FileHandler(location='%s%s%s' % (
            temporary_documentation_folder.path, DOCUMENTATION_BUILD_PATH,
            DISTRIBUTION_BUNDLE_FILE_PATH))
        new_distribution_bundle_file.directory.make_directories()
        distribution_bundle_file.path = new_distribution_bundle_file
        new_distribution_bundle_directory = FileHandler(location='%s%s%s' % (
            temporary_documentation_folder.path, DOCUMENTATION_BUILD_PATH,
            DISTRIBUTION_BUNDLE_DIRECTORY_PATH))
        new_distribution_bundle_directory.make_directories()
        zipfile.ZipFile(distribution_bundle_file.path).extractall(
            new_distribution_bundle_directory.path)
    favicon = FileHandler(location='favicon.png')
    if favicon:
        favicon.copy(target='%s/source/image/favicon.ico' %
            temporary_documentation_folder.path)
    parameter = builtins.dict(builtins.map(lambda item: (
        String(item[0]).delimited_to_camel_case.content.upper(), item[1]
    ), SCOPE.get('documentationWebsite', {}).items()))
    if 'TAGLINE' not in parameter and 'description' in SCOPE:
        parameter['TAGLINE'] = SCOPE['description']
    if 'NAME' not in parameter and 'name' in SCOPE:
        parameter['NAME'] = SCOPE['name']
    __logger__.debug('Found parameter "%s".', json.dumps(parameter))
    parameter.update({
        'CONTENT': CONTENT,
        'CONTENT_FILE_PATH': None,
        'RENDER_CONTENT': False,
        'API_DOCUMENTATION_PATH': ('%s%s' % (
            API_DOCUMENTATION_PATH[1], API_DOCUMENTATION_PATH_SUFFIX
        )) if has_api_documentation else None,
        'DISTRIBUTION_BUNDLE_FILE_PATH':
            DISTRIBUTION_BUNDLE_FILE_PATH if (
                distribution_bundle_file and
                distribution_bundle_file.is_file()
            ) else None
    })
# # python3.5
# #     parameter = Dictionary(parameter).convert(
# #         value_wrapper=lambda key, value: value.replace(
# #             '!', '#%%%#'
# #         ) if builtins.isinstance(value, builtins.str) else value
# #     ).content
    parameter = Dictionary(parameter).convert(
        value_wrapper=lambda key, value: value.replace(
            '!', '#%%%#'
        ) if builtins.isinstance(value, builtins.unicode) else value
    ).content
# #
    if __logger__.isEnabledFor(logging.DEBUG):
        BUILD_DOCUMENTATION_PAGE_COMMAND = \
            BUILD_DOCUMENTATION_PAGE_COMMAND[:-1] + [
                '-debug'
            ] + BUILD_DOCUMENTATION_PAGE_COMMAND[-1:]
    for index, command in builtins.enumerate(BUILD_DOCUMENTATION_PAGE_COMMAND):
        BUILD_DOCUMENTATION_PAGE_COMMAND[index] = \
            BUILD_DOCUMENTATION_PAGE_COMMAND[index].format(
                serializedParameter=json.dumps(parameter), **SCOPE)
    __logger__.info('Use "%s".', ' '.join(BUILD_DOCUMENTATION_PAGE_COMMAND))
    BUILD_DOCUMENTATION_PAGE_COMMAND[-1] = base64_encode(
        BUILD_DOCUMENTATION_PAGE_COMMAND[-1])
    __logger__.info('Run "%s".', ' '.join(BUILD_DOCUMENTATION_PAGE_COMMAND))
    current_working_directory_backup = FileHandler()
    temporary_documentation_folder.change_working_directory()
    Platform.run(
        command=BUILD_DOCUMENTATION_PAGE_COMMAND[0],
        command_arguments=BUILD_DOCUMENTATION_PAGE_COMMAND[1:], error=False,
        log=True)
    current_working_directory_backup.change_working_directory()
    for file in FileHandler():
        if not (file in (temporary_documentation_folder, FileHandler(
            location='.%s' % API_DOCUMENTATION_PATH[1]
        )) or is_file_ignored(file)):
            file.remove_deep()
    documentation_build_folder = FileHandler(location='%s%s' % (
        temporary_documentation_folder.path, DOCUMENTATION_BUILD_PATH
    ), must_exist=True)
    documentation_build_folder.iterate_directory(
        function=copy_repository_file, recursive=True,
        source=documentation_build_folder, target=FileHandler())
    if (Platform.run(
        "/usr/bin/env sudo umount '%s'" %
            temporary_documentation_node_modules_directory.path,
        native_shell=True, error=False, log=True
    )['return_code'] == 0):
        temporary_documentation_folder.remove_deep()
    Platform.run((
        '/usr/bin/env git add --all',
        '/usr/bin/env git commit --message "%s" --all' %
        PROJECT_PAGE_COMMIT_MESSAGE,
        '/usr/bin/env git push', '/usr/bin/env git checkout master'
    ), native_shell=True, error=False, log=True)


@JointPoint
# # python3.5 def create_distribution_bundle_file() -> FileHandler:
def create_distribution_bundle_file():
    '''Creates a distribution bundle file as zip archiv.'''
    if not SCOPE['scripts'].get('export', SCOPE.get(
        'build', False
    )) or Platform.run('/usr/bin/env npm run %s' % (
        'export' if SCOPE['scripts'].get('export') else 'build'
    ), error=False, log=True)['return_code'] == 0:
        __logger__.info('Pack to a zip archive.')
        distribution_bundle_file = FileHandler(
            location=make_secure_temporary_file()[1])
        build_directory = FileHandler(location=DOCUMENTATION_BUILD_PATH)
        if build_directory.is_directory():
            with zipfile.ZipFile(
                distribution_bundle_file.path, 'w'
            ) as zip_file:
                for file in build_directory:
                    __logger__.debug(
                        'Add "%s" to distribution bundle.', file.path)
                    zip_file.write(file._path, file.name)
                    if file.is_directory():
                        for sub_file in file:
                            __logger__.debug(
                                'Add "%s" to distribution bundle.',
                                sub_file.path)
                            zip_file.write(sub_file._path, '%s/%s' % (
                                file.name, sub_file.name))
        else:
            with zipfile.ZipFile(
                distribution_bundle_file.path, 'w'
            ) as zip_file:
                for file in FileHandler():
# # python3.5
# #                     if regularExpression.compile(
# #                         '.+\\.compiled(?:\\.[^.]+(?:\\.map)?)?'
# #                     ).fullmatch(file.name):
                    if regularExpression.compile(
                        '.+\\.compiled(?:\\.[^.]+(?:\\.map)?)?$'
                    ).match(file.name):
# #
                        __logger__.debug(
                            'Add "%s" to distribution bundle.', file.path)
                        zip_file.write(file._path, file.name)
                        if file.is_directory():
                            for sub_file in file:
                                __logger__.debug(
                                    'Add "%s" to distribution bundle.',
                                    sub_file.path)
                                zip_file.write(sub_file._path, '%s/%s' % (
                                    file.name, sub_file.name))
        return distribution_bundle_file


@JointPoint
# # python3.5 def is_file_ignored(file: FileHandler) -> builtins.bool:
def is_file_ignored(file):
    return (
        file.basename.startswith('.') or
        file.basename == 'dummyDocumentation' or file.is_directory() and
        file.name in ['node_modules', 'build'] or file.is_file() and
        file.name in ['params.json'])


@JointPoint
# # python3.5
# # def copy_repository_file(
# #     file: FileHandler, source:FileHandler, target: FileHandler: FileHandler
# # ) -> (builtins.bool, builtins.type(None)):
def copy_repository_file(file, source, target):
# #
    '''Copy the website documentation design repository.'''
    if not (is_file_ignored(file) or file.name == 'readme.md'):
        new_path = FileHandler(location='%s/%s' % (
            target.path,  file.path[builtins.len(source.path):]
        )).path
        __logger__.debug('Copy "%s" to "%s".', file.path, new_path)
        if file.is_file():
            file.copy(target=new_path)
        else:
            FileHandler(location=new_path, make_directory=True)
        return True


@JointPoint
# # python3.5
# # def add_readme(file: FileHandler) -> (builtins.bool, builtins.type(None)):
def add_readme(file):
# #
    '''Merges all readme file.'''
    global CONTENT
    if not is_file_ignored(file):
        if file.basename == 'readme':
            __logger__.info('Handle "%s".', file.path)
            if CONTENT:
                CONTENT += '\n'
            CONTENT += file.content
        return True
# endregion

# region footer
'''
    Preset some variables given by introspection letting the linter know what \
    globale variables are available.
'''
__logger__ = __exception__ = __module_name__ = __file_path__ = \
    __test_mode__ = __test_buffer__ = __test_folder__ = __test_globals__ = None
'''
    Extends this module with some magic environment variables to provide \
    better introspection support. A generic command line interface for some \
    code preprocessing tools is provided by default.
'''
Module.default(name=__name__, frame=inspect.currentframe())
# endregion
# region vim modline
# vim: set tabstop=4 shiftwidth=4 expandtab:
# vim: foldmethod=marker foldmarker=region,endregion:
# endregion
