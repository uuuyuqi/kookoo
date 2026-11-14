# Pane cards (0.1.4 Preview)

Each leaf pane owns one continuous 10pt corner card and a thin outline. A 3pt
leaf inset plus the existing 1pt split separator produces a 7pt visual gutter,
without accumulating margins at nested splits. Terminal inset is 5pt inside
the card, retaining the prior total 8pt content inset. The divider's existing
6pt hit area and drag/SIGWINCH suspension are unchanged.

Only newly created splits opt into a 0.28s presentation spring (0.975 → 1).
Split fractions and terminal grid layout are not animated by this entrance.
The transient flag is consumed once; restored panes and existing siblings
must not replay it when SwiftUI reparents the tree. Reduce Motion skips it.

Pane zoom/restore lives at the right of each pane header, before split-right
and split-down. It targets that pane even if another pane has keyboard focus.
Command-Shift-E and the context menu retain their behavior. Header controls
are excluded from the tab area's double-click-to-zoom-window monitor.

## Verification boundary

Automated tests cover insertion eligibility/one-shot consumption, reduced
motion policy, inset arithmetic, and zoom targeting. Existing pane-tree and
keyboard tests remain applicable. These are not screenshot or live Metal
rendering tests.

Interactive acceptance still needed on macOS:

- Split right/down, nested splits and rapid repeated additions: one subtle
  entrance per new pane; no displaced or blurred terminal after completion.
- Close a pane or transfer its final tab: siblings retain text, identity and
  keyboard focus; no replayed entrance.
- Drag each divider, then zoom/restore a non-focused pane from the header;
  terminal grid settles correctly and input reaches the expected pane.
- Double-click pane zoom: no macOS window zoom.
- Switch workspaces and return: existing panes do not animate again.
- Enable Reduce Motion: insertions are immediate.
- Check light/dark themes and small window sizes: card outline/corners are
  visible without clipping text, search, composer or status controls.

Do not restart a user's running app to run these checks without agreement:
terminal sessions and running agents terminate during an app restart.

## Sidebar card (0.1.5 Preview)

The left sidebar now shares the pane corner radius, outline and outer inset,
while retaining its existing chrome/glass fill. The titlebar and window
traffic-light controls remain outside this card. Full/compact outer widths,
terminal leading offset and the edge resize hit area are unchanged. The
former straight separator is transparent so the two card edges form the
same gutter as adjacent terminal panes. Interactive visual acceptance of
light/dark contrast and collapsed/expanded transitions is still required.
