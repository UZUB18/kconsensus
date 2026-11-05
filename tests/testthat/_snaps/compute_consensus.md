# a unique upper-bound winner triggers an explicit warning

    Code
      compute_consensus(list(test_vote("upper_boundary", 6L)))$boundary_warning
    Condition
      Warning:
      Consensus winner K = 6 is the highest tested K; larger values were not evaluated.
    Output
      [1] TRUE

# malformed and duplicated records cannot manufacture votes

    Code
      compute_consensus(list())
    Condition
      Error:
      ! `recommendations` must be a nonempty list of standardized records.

---

    Code
      compute_consensus(list(list(method = "incomplete")))
    Condition
      Error:
      ! Every recommendation must be a complete standardized method record.

---

    Code
      compute_consensus(list(test_vote("same"), test_vote("same")))
    Condition
      Error:
      ! Method names must be distinct; each method can cast only one vote.

---

    Code
      compute_consensus(list(record))
    Condition
      Error:
      ! Valid methods need a tested preferred K; abstaining methods cannot vote.

