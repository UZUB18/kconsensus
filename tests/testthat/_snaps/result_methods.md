# print gives a short overview instead of the raw list

    Code
      print(result)
    Output
      <kconsensus result>
      Recommended K: 4  (plurality, no majority: 2 of 5 valid votes, 40%)
      Votes: K = 1 (1), K = 3 (1), K = 4 (2), K = 5 (1)
      Flags: single_cluster_vote
      Use summary() for reasons and flags, and plot() for diagnostics.

# summary explains support, runner-up, abstentions, flags and caveats

    Code
      print(s)
    Output
      kconsensus: number of clusters for K-means
      --------------------------------------------
      Recommended K:  4
      Support:        Plurality, no majority (2 of 5 valid votes, 40%)
      Runner-up:      K = 1, 3 and 5 (1 vote each)
      Valid votes:    5 of 6 methods
      Candidate K:    2:6
      Seed:           1
      Gap B:          10
      
      Votes
        K = 1  1 vote   20%
        K = 3  1 vote   20%
        K = 4  2 votes  40%
        K = 5  1 vote   20%
      
      Methods
        Method             Vote  Runner-up  Margin
        Silhouette         4     5          0.01
        Calinski-Harabasz  3     5          20
        Davies-Bouldin     4     5          0.1
        Dunn               5     4          0.05
        Gap Statistic      1     -          -
        WCSS Elbow         -     -          -
        Margin: raw score difference between the best and runner-up K, comparable
        only within one method.
      
      Not voting
        WCSS Elbow [ambiguous]: Automatic selection disabled: no min_strength
          supplied.
      
      Flags
        ! Gap Statistic voted for K = 1 (no subdivision), while 4 other methods
          voted for K >= 2. Silhouette, Calinski-Harabasz, Davies-Bouldin and Dunn
          did not evaluate K = 1, so those votes do not test it.
      
      Weak preference only: K = 4 leads without a majority, so the methods
      disagree. Inspect plot(result, type = "indices") before choosing K. Check the
      flags above.
      
      Note: vote percentages describe agreement between methods, not statistical
      confidence.
      Data were used as supplied; kconsensus did not standardize them.

# the result methods reject malformed objects

    Code
      summary.kconsensus_result(list(a = 1))
    Condition
      Error:
      ! `object` must be a valid `kconsensus_result` object.

---

    Code
      as.data.frame.kconsensus_result(list(a = 1))
    Condition
      Error:
      ! `x` must be a valid `kconsensus_result` object.

---

    Code
      as.data.frame(plurality_fixture(), what = "fits")
    Condition
      Error in `match.arg()`:
      ! 'arg' should be one of "methods", "agreement", "scores"

