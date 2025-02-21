# Requesting Access

It's recommended to [request access](https://docs.gitlab.com/ee/user/group/index.html#request-access-to-a-group) to the [Xonotic project group](https://gitlab.com/xonotic).  Forking our repositories and submitting merge requests from there will work but you won't be able to use our CI setup for the [xonotic-data.pk3dir](https://gitlab.com/xonotic/xonotic-data.pk3dir) repo.

Please let us know your GitLab username [on Matrix](https://xonotic.org/chat) so that we know you're legit.


# Licensing

A condition for write (push) access and submission of merge requests is that **you agree that any code or other data you push will be licensed under the [GNU General Public License, version 3](https://www.gnu.org/licenses/gpl-3.0.html), or any later version.**

**Exceptions:** if the directory or repository your changes apply to contains a LICENSE or COPYING file indicating another license or a dual license, then **you agree that your pushed code or other data will be licensed as specified in that file.**  Examples of subdirectories and repositories with a dual license or a different license:
* [xonotic-data.pk3dir/qcsrc/lib/warpzone](https://gitlab.com/xonotic/xonotic-data.pk3dir/-/tree/master/qcsrc/lib/warpzone) - dual-licensed with GNU GPLv2 (or any later version), or MIT license.
* [xonstat-go](https://gitlab.com/xonotic/xonstat-go/) - licensed with [GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.html)

In case the code or other data you pushed was not created by you, it is your responsibility to ensure proper licensing.

See also the primary licensing document [COPYING](COPYING)


# Technical

The Xonotic repo structure and git HOWTO are on the [Xonotic Git wiki page](https://gitlab.com/xonotic/xonotic/-/wikis/Git).  
Build tools are documented on the [Repository_Access wiki page](https://gitlab.com/xonotic/xonotic/wikis/Repository_Access).


# Policies

### For all Developers

- Branches should be named `myname/mychange`. For instance, if your name is Alex and the change you are committing is a menu fix, use something like `alex/menufix`.
- Ask the branch owner before pushing to someone else's branch.

### For Maintainers

- During a release freeze only user-visible fixes/polishing and documentation may be merged/pushed to master, other changes (e.g. new features, redesigns, refactors) must be discussed with the team first.
- Pushing to someone else's branch is allowed if changes are required for merging the branch AND the owner has left the project or indicated they won't develop the branch further.
- Any change pushed directly to `master` must be top quality: no regressions, no controversy, thoughtful design, great perf, clean and readable, successful pipeline, compliant with the Code Style below, no compiler warnings.
- When merging, if the commit history is "messy" (contains commits that just fix the previous commit(s), and/or commits that don't compile and run, and/or poorly described commits) the MR should be squash merged.  Clean concise commit history is useful and is to be merged intact.
- Force pushes must not be made to the default branch (typically `master` or `main`).


# Code Style

This should be approximately consistent with the [DarkPlaces style](https://gitlab.com/xonotic/darkplaces/-/blob/master/CONTRIBUTING.md).

### All code submitted should follow the Allman style for the most part.

- In statements, the curly brace should be placed on the next line at the
  same indentation level as the statement. If the statement only involves
  a single line, preferably don't use braces.

	```c
	// Example:
	if (foo == 1)
	{
		Do_Something();
		Do_Something_Else();
	}
	else
		Do_Something_Else_Else();

	if (bar == 1)
		Do_Something_Else_Else_Else();
	```

- Use tabs for indentation.  
  Use spaces subsequently when aligning text such as the
  parameters of multi-line function calls, declarations, or statements.

	```c
	switch (foo)
	{
		case 1337:   I_Want();  break;
		case 0xffff: These();   break;
		default:     Aligned();
	}

	AFuncWith(way,
	          too,
	          many,
	          args & STUFF);
	```

- If possible, try to keep individual lines of code less than 100 characters.

- As in the example above, it would be preferable to attempt to limit
  line length when it comes to very long lists of function arguments
  by manually wrapping the lines, but not prematurely.

- Pointer operators should be placed on the right-hand side and type casts should have a space between the type and the pointer.

	```c
	int foo = 1;
	int *bar = &foo;
	int *baz = (int *)malloc(5);
	```

- Place a space after each comma when listing parameters or defining array/struct members,
  and after each semicolon of a `for` loop.  
  Don't place a space between the function name and the `(` and don't place a space between the `(` or `)` and the parameter.

- Significant documentation comments should be formatted like so:

	```c
	/*
	 * This is a multi-line comment.
	 * Sometimes, I dream about cheese.
	 */
	```

  But this is okay too:

	```c
	/* This is another multi-line comment.
	 * Hiya! How are you?
	 */
	```

  Place a space between the `//` or `#` and the comment text (_not_ recommended for commented lines of code):

	```c
	// Do you know who ate all the doughnuts?
	//ItWasThisAwfulFunc(om, nom, nom);
	```

- Use parentheses to separate bitwise and logical versions of an operator when they're used in the same statement.

	```c
	foo = (bar & FLAG) && baz;
	```

- Variables names should preferably be in either lowerCamelCase or snake_case
  but a cautious use of lowercase for shorter names is fine.  
  Functions in CamelCase, macros in UPPERCASE.  
  Underscores should be included if they improve readability.

- TODO notes which are time sensitive and pending on a release period to begin or end in
  order to be actionable should use the following formatting.  
  The version number is a git release tag such as `xonotic-v0.8.2`,
  existing tags can be found [here](https://gitlab.com/xonotic/xonotic/-/tags).

	```c
	// XONRELEASE TODO: xonotic-v0.9 before release drink water
	// XONRELEASE TODO: xonotic-v0.8.6 before release candidate eat food
	// XONRELEASE TODO: xonotic-v0.8.5 after release hydrate more
	// XONRELEASE TODO: xonotic-v0.8.2 after release candidate take a shower
	```

- If following these guidelines in any manner would make any code less
  readable or harder to follow, ***ignore them***. This section is only
  guidelines, not rules. We're not going to beat you over the head in
  merge requests because you misplaced a dereference operator.

  For example, in some situations, placing the block on the same line as
  the condition would be okay because it looks cleaner:

	```c
	if (foo)  DoSomething();
	if (bar)  Do_Something_Else();
	if (far)  Near();
	if (boo)  AHH("!!!\n");
	```
