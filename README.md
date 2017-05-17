# cerner\_splunk\_ingredient Cookbook

Resource cookbook which provides custom resources for installing and managing Splunk.

These resources can:

- Install Splunk via downloadable package or archive
- Start and stop the Splunk service

## Requirements

Chef >= 12.16
Ruby >= 2.3.1

Supports Linux and Windows based systems with package support for Debian, Redhat,
and Windows.

Using resources of this cookbook to install and run Splunk means you agree to Splunk's EULA packaged with the software,
also available online at <http://www.splunk.com/en_us/legal/splunk-software-license-agreement.html>

---

## Resources

### splunk\_install

Manages an installation of Splunk

Note: There are more specific resources available if you wish to override how Splunk is installed.
For example, if you want to force install from .rpm you can use splunk\_install\_redhat, or to install
from archive (tgz for Linux and zip for Windows) use splunk\_install\_archive.

#### Action _:install_

Installs Splunk or Universal Forwarder.

Properties:

| Name      |               Type(s)               | Required | Default                                          | Description                                                                                                                                                                                                                                                            |
| :-------- | :---------------------------------: | :------: | :----------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| package   | `:splunk` or `:universal_forwarder` |  **Yes** |                                                  | Specifies the Splunk package to install. You must specify the package, or name the resource for the package; for example, `package :splunk` or `splunk_install 'universal_forwarder' do ... end`                                                                       |
| version   |                String               |  **Yes** |                                                  | Version of Splunk to install                                                                                                                                                                                                                                           |
| build     |                String               |  **Yes** |                                                  | Build number of the version                                                                                                                                                                                                                                            |
| user      |                String               |    No    | `'splunk'` on Linux, current user on Windows     | User that should own the splunk installation. Currently not modifiable on Windows. Make sure you don't use a different user for running Splunk that has insufficient read/write access, or Splunk won't start!                                                         |
| group     |                String               |    No    | Value of user property on Linux, None on Windows | Group that should own the splunk installation. Currently not modifiable on Windows.                                                                                                                                                                                    |
| base\_url |                String               |    No    | `'https://download.splunk.com/products'`         | Base url to pull Splunk packages from. Use this if you are mirroring the downloads for Splunk packages. The resource will append the version, os, and filename to the url like so: `{base_url}/splunk/releases/0.0.0/linux/splunk-0.0.0-a1b2c3d4e5f6-Linux-x86_64.tgz` |

Specific to splunk\_install\_archive

| Name         | Type(s) | Required | Default                         | Description                                                                                                                                 |
| :----------- | :-----: | :------: | :------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------ |
| install\_dir |  String |    No    | Depends on platform and package | Manually specify the install directory for Splunk. This can only be done when installing from an archive, otherwise it will raise an error. |

#### Action _:uninstall_

Removes Splunk or Universal Forwarder and all its configuration.

Properties:

| Name    |               Type(s)               |                Required               | Default | Description                                                                                                                                                                                                                                      |
| :------ | :---------------------------------: | :-----------------------------------: | :------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| package | `:splunk` or `:universal_forwarder` | **Yes, unless install\_dir is given** |         | Specifies the Splunk package to uninstall. If you did not specify the install\_dir, then you must specify the package, or name the resource for the package; for example, `package :splunk` or `splunk_install 'universal_forwarder' do ... end` |

##### Run State

`splunk_install` _stores the current installation state to the [run state](https://docs.chef.io/recipes.html#node-run-state)._
This contains data such as install directory and package so that subsequent resources can assume these values and avoid
repetition. For example, you would be able to execute `splunk_conf` after a `splunk_install` and it will inherit the
package of that last evaluated resource. If the install resource does nothing (installation already exists), it will
still load the run state from the existing installation.

You can access this state from your own recipe or resource, too. An example of the run state:

```Ruby
node.run_state['splunk_ingredient'] = {
  'installations' => {
    '/opt/splunk' => {    # Install directory
      name: 'splunk',     # Resource name
      package: :splunk,
      version: '5.5.5',
      build: 'a1b2c3d4e5f6',
      x64: true           # Architecture of the Splunk install, determined by system supported architecture.
    }
  },
  'current_installation' => {
    name: 'splunk',
    package: :splunk,
    ...
    # References the last evaluated splunk_install; same as above, being the only install.
  }
}
```

### splunk\_service

Manages an installation of Splunk. Requires splunk\_install to be evaluated first.

**The following actions (start and restart) share the same properties:**

#### Action _:start_

Starts the Splunk daemon if not already running.
If the ulimit is changed, invokes a restart of the daemon at the end of the run.

#### Action _:restart_

Restarts the Splunk daemon, or starts it if not already running.

Properties:

| Name         |               Type(s)               |                Required               | Default                               | Description                                                                                                                                                                                                                                   |
| :----------- | :---------------------------------: | :-----------------------------------: | :------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| package      | `:splunk` or `:universal_forwarder` | **Yes, unless install\_dir is given** |                                       | Specifies the installed Splunk package. If you did not specify the install\_dir, then you must specify the package, or name the resource for the package; for example, `package :splunk` or `splunk_service 'universal_forwarder' do ... end` |
| install\_dir |                String               |                   No                  | Same as splunk\_install               | The install directory of Splunk. If you installed to a different directory than the default, you should provide this. If install\_dir is given, you do not need package.                                                                      |
| ulimit       |               Integer               |                   No                  | Start up script ulimit or user ulimit | Open file ulimit to give Splunk. This sets the ulimit in the start up script (if it exists) and for the given user in `/etc/security/limits.d/`. -1 translates to `'unlimited'`                                                               |

#### Action _:stop_

Stop the Splunk daemon if it is running.

Properties:

| Name         |               Type(s)               |                Required               | Default                 | Description                                                                                                                                                                                                                                   |
| :----------- | :---------------------------------: | :-----------------------------------: | :---------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| package      | `:splunk` or `:universal_forwarder` | **Yes, unless install\_dir is given** |                         | Specifies the installed Splunk package. If you did not specify the install\_dir, then you must specify the package, or name the resource for the package; for example, `package :splunk` or `splunk_service 'universal_forwarder' do ... end` |
| install\_dir |                String               |                   No                  | Same as splunk\_install | The install directory of Splunk. If you installed to a different directory than the default, you should provide this. If install\_dir is given, you do not need package.                                                                      |

#### Action _:init_

Executes Splunk's first time run, accepting the license agreement if applicable. This does not start Splunk, only runs its initial setup.

Properties:

| Name         |               Type(s)               |                Required               | Default                 | Description                                                                                                                                                                                                                                   |
| :----------- | :---------------------------------: | :-----------------------------------: | :---------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| package      | `:splunk` or `:universal_forwarder` | **Yes, unless install\_dir is given** |                         | Specifies the installed Splunk package. If you did not specify the install\_dir, then you must specify the package, or name the resource for the package; for example, `package :splunk` or `splunk_service 'universal_forwarder' do ... end` |
| install\_dir |                String               |                   No                  | Same as splunk\_install | The install directory of Splunk. If you installed to a different directory than the default, you should provide this. If install\_dir is given, you do not need package.                                                                      |

#### Action _:desired\_restart_

Intended to be run or notified immediately. This action creates a marker file that triggers a delayed restart later.
The splunk\_service always checks for this marker file at the end of the run. This is very useful when you perform an action
that should cancel an unnecessary restart (such as stopping or starting the service). The marker file is removed in these
cases and the delayed restart is effectively cancelled. It also helps when the run fails attempting to restart, because it
will try to restart again on the next run (assuming the marker is not cleared beforehand).

You should notify this action :immediately when you have changes that demand a restart of Splunk.

### splunk\_conf

Manages configuration for an installation of Splunk. Requires splunk\_install to be evaluated first.

#### Action _:configure_

Applies configuration to .conf files.
You should know where the .conf file is that you wish to modify, as you must provide the path from `$SPLUNK_HOME/etc`.

You can specify the scope as you would in the real path to the file (`system/local/indexes.conf`) or use the `scope`
property and specify this path: `system/indexes.conf`. The resource will modify local config if no scope is provided.

Properties:

| Name         |               Type(s)               |         Required        | Default                                          | Description                                                                                                                                                                                                                                       |
| :----------- | :---------------------------------: | :---------------------: | :----------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| path         |          String or Pathname         | **Yes (resource name)** |                                                  | Path of the .conf file from `$SPLUNK_HOME/etc`. The intermediate directory determining scope is optional. Examples: `system/indexes.conf` or `system/local/indexes.conf`.                                                                         |
| package      | `:splunk` or `:universal_forwarder` |            No           | Package of the current install in run state      | Specifies the installed Splunk package. If you did not specify the install\_dir, then you may specify the package (`:splunk` or `:universal_forwarder`) otherwise the resource will refer to the most recently evaluated splunk\_install resource |
| install\_dir |                String               |            No           | Path of the current install in run state         | The install directory of Splunk. If you installed to a different directory than the default, you should provide this. If install\_dir is given, you do not need package.                                                                          |
| scope        |   `:local`, `:none`, or `:default`  |            No           | `:local`                                         | Scope of the configuration to modify. In most circumstances, you should _not_ change this. `:none` will disable checking or modifying scope in the path.                                                                                          |
| config       |                 Hash                |         **Yes**         |                                                  | Configuration to apply to the .conf file. This hash is structured as follows: `{ section: { key: 'value' } }`. See below for more detailed explanation of the config property.                                                                    |
| user         |            String or nil            |            No           | Owner of the current Splunk installation, if any | User that will be used to write to the .conf files.                                                                                                                                                                                               |
| group        |            String or nil            |            No           | Group of the current Splunk installation, if any | Group that will be used to write to the .conf files.                                                                                                                                                                                              |
| reset        |            true or false            |            No           | false                                            | When specified as true, entirely replaces existing config. By default, config is merged into the existing conf file.                                                                                                                              |

#### Configuration

The configuration you provide will be evaluated against the existing config file (if it exists, and if reset is not specified).
Symbol or string keys are irrelevant as the provided config is converted to string keys and values before being used.

Some things to be aware of when using the configuration resource:

##### **"Global" properties are evaluated under `[default]`**

Properties defined at the top of the .conf file and not considered to be part of a section are assumed to be `[default]`
per Splunk documentation: <http://docs.splunk.com/Documentation/Splunk/6.4.2/Admin/Propsconf#GLOBAL_SETTINGS>

##### **Comments are not preserved**

The configuration resource can't evaluate and merge the configuration on disk and by Chef while keeping the
relevant comments and whitespace. The .conf file will be rewritten with the merged config and uniform whitespace.

##### **Example of how the configuration is written out to disk:**

```Ruby
splunk_conf 'system/test.conf' do
  config(
    testing: {
      one: 1,
      two: 2,
      three: 3
    },
    section: {
      key: :value
    }
  )
end
```

`/opt/splunk/etc/system/local/test.conf`:

```INI
# Warning: This file is managed by Chef!
# Comments will not be preserved and configuration may be overwritten.

[testing]
one = 1
two = 2
three = 3

[section]
key = value
```

##### Advanced Usage

The configuration resource also can evaluate Procs in place of, or within, your config hash.
This approach is beneficial if you want to write your config based on the current values, or
you don't know all of your configuration values at compile time but can evaluate them at
converge time.

There are three approaches you can take to configuring with procs or lambdas: Top-level, Section-level, and Key-level.
Each level provides a context object, providing the path of the current file and the app, section, and key when applicable.

###### Top-level Evaluation

Top-level evaluation is simple in concept, as you are given the entire existing config as a hash and you
return the desired config.

In this example, all of the keys and values in the conf file are turned into lowercase strings.

```Ruby
splunk_conf 'system/test.conf' do
  config(
    lambda do |_, conf|
      conf.map do |section, props|
        [section.to_s.downcase, props.map { |k, v| [k.to_s.downcase, v.to_s.downcase] }.to_h]
      end.to_h
    end
  )
end
```

###### Section-level Evaluation

Section-level evaluation allows you to evaluate the config key values for a specific section without being
responsible for regurgitating all of the config you didn't want to modify.

In this example, only a specific section's contents are turned into lowercase strings. The rest is
merged as usual.

```Ruby
splunk_conf 'system/test.conf' do
  config(
    testing: {
      one: 1,
      four: 4
    },
    section: ->(context, props) { props.map { |k, v| [k.to_s.downcase, v.to_s.downcase] }.to_h }
  )
end
```

###### Value-level Evaluation

Value-level evaluation, while possible from a section-level lambda, is the more common case and thus is supported for sheer
ease of use. This is especially handy when you want to produce some value for a particular key and don't want to bother with
nesting the rest of the section in your Proc. If there is a case where you're applying a Proc to values whose keys you don't know,
this becomes a necessary functionality.

In this example, if the value is an Array object, it is converted into a comma spaced string using join.

```Ruby
splunk_conf 'system/test.conf' do
  config(
    testing: {
      servers: ->(context, value) { value.is_a?(Array) ? value.join(', ') : value }
    }
  )
end
```

###### The Context object

A ConfContext object is passed as the first parameter to any splunk\_conf proc. It contains contextual information such as
path of the current file, current section (for section-level and key-level procs), and current key (for key-level procs).
It also attempts to determine the current app from the path, if any.

The available accessors are `#path`, `#app`, `#section`, and `#key`. Note that the context object will be frozen when provided to the proc.

Consider the value-level example above:

```Ruby
splunk_conf 'system/test.conf' do
  config(
    testing: {
      servers: ->(context, value) { value.is_a?(Array) ? value.join(', ') : value }
    }
  )
end
```

The following statements would be true for the context object:

```Ruby
lambda do |context, value|
  context.path == '/opt/splunk/etc/system/local/test.conf'
  context.app == 'system'
  context.section == 'testing'
  context.key == 'servers'
  [context.key, value]
end
```

### splunk\_app\_\*

A collection of resources to install and manage Splunk Apps.

#### Resources

##### splunk\_app\_custom

Creates or updates a custom Splunk app, to be configured entirely via Chef. A new custom app will create the app directory and
necessary sub-directories, but the files and configuration of the app must be populated via Chef resources. There is no upgrade
strategy for this type of app; directories will be created if they do not exist, and all further configuration is created or updated
from the configs, files, and metadata properties of this resource. You can use version to control updating of this app if you
set a version in app.conf.

##### splunk\_app\_package

Installs or updates a Splunk app from a package/archive.

#### Action _:install_

Install or upgrade a Splunk App.

##### Properties for splunk\_app\_custom

| Name         |                  Type(s)                 |           Required          | Default                                     | Description                                                                                                                                                                                                                                       |
| :----------- | :--------------------------------------: | :-------------------------: | :------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| name         |                  String                  |   **Yes (resource name)**   |                                             | Name of the app to install.                                                                                                                                                                                                                       |
| package      |    `:splunk` or `:universal_forwarder`   |              No             | Package of the current install in run state | The installed Splunk package. If you did not specify the install\_dir, then you may specify the package (`:splunk` or `:universal_forwarder`) otherwise the resource will refer to the most recently evaluated splunk\_install resource           |
| install\_dir |                  String                  |              No             | Path of the current install in run state    | The install directory of Splunk. If you did not specfiy the package, then you may specify the install\_dir otherwise the resource will refer to the most recently evaluated splunk\_install resource                                              |
| app\_root    | String or `:shcluster` or `:master_apps` |              No             | Standard apps directory                     | The root directory to install the app. Given path can be relative (to ${SPLUNK\_HOME}/etc) or absolute. You can give `'deployment-apps'`, `:shcluster`, or `:master_apps` to install the app to those respective cluster configuration locations. |
| version      |                  String                  | **Yes if app is versioned** |                                             | Version of the app to install. This is required if the app has a version in its app.conf, and will only install/upgrade if the version is different or the app is not already installed. If the app has no version, this does nothing.            |
| configs      |                   Proc                   |              No             |                                             | Proc containing `splunk_conf` resources. The resources will behave similarly to normal, except the config will be placed relative to the app directory rather than relative to the Splunk installation, and you can not change the scope.         |
| files        |                   Proc                   |              No             |                                             | Proc containing miscellaneous resources for manipulating the app directory. This is ideally directories, templates, and files. The Proc will be given an absolute app path parameter for you to use in these resources.                           |
| metadata     |                   Hash                   |              No             | {}                                          | Configuration to apply to the metadata (default.meta for custom apps). See splunk\_conf for more info, and also below for special handling of the `access` key.                                                                                   |

##### Properties for splunk\_app\_package

| Name         |                  Type(s)                 |           Required          | Default                                     | Description                                                                                                                                                                                                                                       |
| :----------- | :--------------------------------------: | :-------------------------: | :------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| name         |                  String                  |   **Yes (resource name)**   |                                             | Name of the app to install.                                                                                                                                                                                                                       |
| package      |    `:splunk` or `:universal_forwarder`   |              No             | Package of the current install in run state | The installed Splunk package. If you did not specify the install\_dir, then you may specify the package (`:splunk` or `:universal_forwarder`) otherwise the resource will refer to the most recently evaluated splunk\_install resource           |
| install\_dir |                  String                  |              No             | Path of the current install in run state    | The install directory of Splunk. If you did not specfiy the package, then you may specify the install\_dir otherwise the resource will refer to the most recently evaluated splunk\_install resource                                              |
| app\_root    | String or `:shcluster` or `:master_apps` |              No             | Standard apps directory                     | The root directory to install the app. Given path can be relative (to ${SPLUNK\_HOME}/etc) or absolute. You can give `'deployment-apps'`, `:shcluster`, or `:master_apps` to install the app to those respective cluster configuration locations. |
| source\_url  |                  String                  |           **Yes**           |                                             | Source url to use for installing an app package.                                                                                                                                                                                                  |
| version      |                  String                  | **Yes if app is versioned** |                                             | Version of the app to install. This is required if the app has a version in its app.conf, and will only install/upgrade if the version is different or the app is not already installed. If the app has no version, this does nothing.            |
| configs      |                   Proc                   |              No             |                                             | Proc containing `splunk_conf` resources. The resources will behave similarly to normal, except the config will be placed relative to the app directory rather than relative to the Splunk installation, and you can not change the scope.         |
| files        |                   Proc                   |              No             |                                             | Proc containing miscellaneous resources for manipulating the app directory. This is ideally directories, templates, and files. The Proc will be given an absolute app path parameter for you to use in these resources.                           |
| metadata     |                   Hash                   |              No             | {}                                          | Configuration to apply to the metadata (local.meta for non-custom apps). See splunk\_conf for more info, and also below for special handling of the `access` key.                                                                                 |

#### Action _:uninstall_

Uninstalls an app, completely removing it and its files.
Note: You can use any sub-resource or `splunk_app` to uninstall apps.

Properties:

| Name         |               Type(s)               |         Required        | Default                                     | Description                                                                                                                                                                                                                             |
| :----------- | :---------------------------------: | :---------------------: | :------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| name         |                String               | **Yes (resource name)** |                                             | Name of the app to uninstall.                                                                                                                                                                                                           |
| package      | `:splunk` or `:universal_forwarder` |            No           | Package of the current install in run state | The installed Splunk package. If you did not specify the install\_dir, then you may specify the package (`:splunk` or `:universal_forwarder`) otherwise the resource will refer to the most recently evaluated splunk\_install resource |
| install\_dir |                String               |            No           | Path of the current install in run state    | The install directory of Splunk. If you did not specfiy the package, then you may specify the install\_dir otherwise the resource will refer to the most recently evaluated splunk\_install resource                                    |

#### Metadata

The metadata property accepts a config hash, just as `splunk_conf` would (it basically calls `splunk_conf` behind the scenes), but there is one
important operation that is performed before writing the config. It looks in each section for an `access` key, and checks if the value is a hash.
If this is the case, then it parses this hash into a string. This is part of a special syntax to make configuring read/write permissions via Chef easier.

For example, if I want to set the following permissions for all views on the app, I might write:

```INI
[views]
access = read : [ * ], write : [ admin, power ]
```

When using splunk\_app's metadata property, however, I can write the following hash to the same effect:

```Ruby
splunk_app 'test_app' do
  ...
  metadata(views: { access: { read: '*', write: [ 'admin', 'power' ] } })
end
```

This helps when using programmatic values or large arrays of roles, though you _can_ still use the appropriate string instead of the Hash syntax.

---

## Contributing

Check out the [Github Guide to Contributing](https://guides.github.com/activities/contributing-to-open-source/)
for some basic tips on contributing to open source projects, and make sure to read our [Contributing Guidelines](CONTRIBUTING)
before submitting an issue or pull request.

## License and Authors

- Author:: Alec Sears (alec.sears@cerner.com)

```text
Copyright:: 2017, Cerner Innovation, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
