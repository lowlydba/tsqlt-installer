# tSQLt Installer Action

## Description

A Github Action to install tSQLt on CI databases for unit testing.

## Action Type

Composite

## Author

@lowlydba

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

## Notes

If targeting Azure SQL, version `1-0-5873-27393` must be used. See <https://github.com/tSQLt-org/tSQLt/issues/70> for more information.

## Usage

TBD
