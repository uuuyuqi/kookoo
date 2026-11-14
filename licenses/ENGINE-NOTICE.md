# Kookoo terminal engine: third-party notices

Kookoo embeds a modified Ghostty terminal engine. Ghostty.app does not need to
be installed. Copyright and license texts for the engine and its dependencies
are in the adjacent EngineLicenses directory, indexed by manifest.json.

Ghostty is MIT licensed. This is not a claim that every dependency is MIT:
libintl is statically linked under LGPL 2.1; FreeType uses the included FTL terms;
font files carry their included OFL and reserved-font-name terms. Other component
licenses and notices are included separately.

The corresponding-source materials accompanying this distribution contain the
pinned engine source, dependency source, existing patch, build instructions and
the matching Kookoo application source. They describe how to modify libintl,
rebuild the engine and relink the application without a maintainer signing key.
For this purpose, modification and reverse engineering for debugging such
modifications are permitted under the applicable LGPL terms. Ad-hoc signing
does not imply Developer ID signing or notarization; system policy may still
require a user's approval.

This is a community-maintained build, not an official Ghostty distribution or
endorsement. Existing Ghostty configuration compatibility is preserved.
