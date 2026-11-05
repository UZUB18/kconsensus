# kconsensus 0.0.0.9000

* `kconsensus()` provides a public calculation interface retaining fitted partitions, full method evidence, eligibility and descriptive vote agreement.
* `plot()` supports consensus bars, raw diagnostic curves and method-by-K evidence matrices as customizable ggplot objects.
* `status` now grades the support for the leading K as `"unanimous"`, `"majority"` (more than half of the valid votes) or `"plurality"` (most votes but no majority), alongside `"tie"` and `"no_valid_votes"`. It replaces `"unique_winner"`, which reported a 2-of-5 vote the same way as a unanimous one. The consensus plot labels a plurality leader as having no majority.
* New `flags` field with descriptive notes: `upper_boundary`, `lower_boundary` (the winner is the smallest K that every method voting for it evaluated) and `single_cluster_vote` (a method votes for K = 1 while others vote for K >= 2). Flags never change a vote.
* New `print()`, `summary()` and `as.data.frame()` methods. `print()` gives a short overview instead of dumping the result list; `summary()` explains the support, runner-up, abstentions, flags and caveats; `as.data.frame()` returns the methods, agreement or long-format scores table.
* `kconsensus()` no longer stops when a calculation fails part-way. A K-means error or non-convergence at one K, a non-finite index value, or a Gap failure makes only the affected methods abstain, with the reason recorded and a warning listing the failures. Invalid arguments (`B`, `elbow_min_strength`, data, `k`, `seed`) are now all checked before any fitting starts.
* The README now describes the package with a worked example, and a new vignette, `vignette("choosing-k")`, walks through a dataset where the methods agree and one where they do not.
