## How to Open an Alchemy-Resource Ticket

* Before you open a ticket or send a pull request, search for previous discussions about the same feature or issue. Add to the earlier ticket if you find one.

* Before sending a pull request for a feature or bug fix, be sure to have the existing tests passing, and additional tests for your feature or fix.

* Use the same coding style as the rest of the codebase.

* All pull requests should be made to the `master` branch.

## Alterations to the README or documentation

* To make alterations to the `README.md` please alter the `scr/alchemy-resource.litcoffee` file then run `npm run-script doc`.  That will run the below command which will update the `README.md` file and regenerate the documentation.  

```
cat src/alchemy-resource.litcoffee > README.md && docco -l linear src/alchemy-resource.litcoffee && docco src/*.coffee -o docs/src && docco examples/*.coffee -o docs/examples
```
* When any changes are made to any of the source files documentation please also run `npm run-script doc` before commiting those change to ensure all the generated documentation is kept up-to-date.
