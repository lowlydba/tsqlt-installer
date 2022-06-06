# tSQLt Installer Action

[![Windows](https://github.com/lowlydba/tsqlt-installer/actions/workflows/windows.yml/badge.svg)](https://github.com/lowlydba/tsqlt-installer/actions/workflows/windows.yml)
[![Linux](https://github.com/lowlydba/tsqlt-installer/actions/workflows/linux.yml/badge.svg)](https://github.com/lowlydba/tsqlt-installer/actions/workflows/linux.yml)
[![Lint](https://github.com/lowlydba/tsqlt-installer/actions/workflows/linter.yml/badge.svg)](https://github.com/lowlydba/tsqlt-installer/actions/workflows/linter.yml)

## Description

A Github Action to install [tSQLt](https://github.com/tSQLt-org/tSQLt) on SQL Server and AzureSQL databases for unit testing.

Pull requests are welcome!

## Action Type

Composite

## Author

[@lowlydba](https://github.com/lowlydba)

## Inputs

* `sql-instance`:

    *Description*: Target SQL instance.

    *Default*: `localhost`

* `database`:

    *Description*: Target database to install to.

    *Default*: `master`

* `user`:

    *Description*: Optional user for SQL authentication.

* `password`:

    *Description*: Optional password for SQL authentication.

* `version`:

    *Description*: Version to install.

    *Default*: `latest`

* `create-database`:

    *Description*: Create database if it doesn't exist.

    *Default*: `false`

* `update`:

    *Description*: Uninstalls and reinstalls if tSQLt is already present.

    *Default*: `false`

## Example Workflows

To install using Windows authentication:

```yml
on: [push]

jobs:
  windows-auth-tsqlt:
    name: Test installting tSQLt with Windows auth
    runs-on: windows-latest

  steps:
    - uses: actions/checkout@v2

    - name: Install SQL Server
      uses: potatoqualitee/mssqlsuite@v1.4
      with:
        install: sqlengine

    - name: Install tSQLt with Windows auth
      uses: lowlydba/tsqlt-installer@v1
      with:
        sql-instance: localhost
        database: master
        version: latest
```

To install using SQL authentication:

```yml
on: [push]

jobs:
 windows-auth-tsqlt:
  name: Test installting tSQLt with SQL auth
  runs-on: ubuntu-latest
  services:
    sqlserver:
      image: mcr.microsoft.com/mssql/server:2019-latest
      ports:
        - 1433:1433
      env:
        ACCEPT_EULA: Y
        SA_PASSWORD: verystrongindeed

    steps:
      - uses: actions/checkout@v2

      - name: Install tSQLt with SQL auth
        uses: lowlydba/tsqlt-installer@v1
        with:
          sql-instance: localhost
          database: master
          version: latest
          user: sa
          password: verystrongindeed
```

## Notes

* Any invalid version strings are equal to `latest`
* Known version strings:
  * `1-0-5873-27393` - For SQL 2005 and Azure SQL.
* Ensure firewall exceptions are in place for Azure SQL targets.
