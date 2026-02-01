<div align="center">
  <img src="assets/LOGO.png" alt="tuinix logo" width="80" height="80">

  # AI/LLM Tool Policy
</div>

## Policy

tuinix's policy is that contributors can use whatever tools they would like to
craft their contributions, but there must be a **human in the loop**.
Contributors must read and review all Large Language Model (LLM)-generated code
or text before they ask other project members to review it. The contributor is
always the author and is fully accountable for their contributions. Contributors
should be sufficiently confident that the contribution is high enough quality
that asking for a review is a good use of scarce maintainer time, and they
should be **able to answer questions about their work** during review.

We expect that new contributors will be less confident in their contributions,
and our guidance to them is to **start with small contributions** that they can
fully understand to build confidence. We aspire to be a welcoming community that
helps new contributors grow their expertise, but learning involves taking small
steps, getting feedback, and iterating. Passing maintainer feedback to an LLM
doesn't help anyone grow, and does not sustain our community.

Contributors are expected to **be transparent and label contributions that
contain substantial amounts of tool-generated content**. Our policy on labelling
is intended to facilitate reviews, and not to track which parts of tuinix are
generated. Contributors should note tool usage in their pull request description,
commit message, or wherever authorship is normally indicated for the work. For
instance, use a commit message trailer like `Assisted-by: <name of code
assistant>`. This transparency helps the community develop best practices and
understand the role of these new tools.

This policy includes, but is not limited to, the following kinds of
contributions:

- Code, usually in the form of a pull request
- Design proposals
- Issues or security vulnerabilities
- Comments and feedback on pull requests

## Details

To ensure sufficient self-review and understanding of the work, it is strongly
recommended that contributors write PR descriptions themselves (if needed, using
tools for translation or copy-editing). The description should explain the
motivation, implementation approach, expected impact, and any open questions or
uncertainties to the same extent as a contribution made without tool assistance.

An important implication of this policy is that it bans agents that take action
in our digital spaces without human approval, such as the GitHub `@claude`
agent. Similarly, automated review tools that publish comments without human
review are not allowed. However, an opt-in review tool that **keeps a human in
the loop** is acceptable under this policy. As another example, using an LLM to
generate NixOS module configurations, which a contributor manually reviews for
correctness, tests, edits, and then posts as a PR, is an approved use of tools
under this policy.

## Extractive Contributions

The reason for our "human-in-the-loop" contribution policy is that processing
patches, PRs, comments, issues, and security alerts to tuinix is not free -- it
takes a lot of maintainer time and energy to review those contributions! Sending
the unreviewed output of an LLM to open source project maintainers *extracts*
work from them in the form of design and code review, so we call this kind of
contribution an "extractive contribution".

Our **golden rule** is that a contribution should be worth more to the project
than the time it takes to review it. These ideas are captured by this quote from
the book [Working in Public](https://press.stripe.com/working-in-public) by
Nadia Eghbal:

> "When attention is being appropriated, producers need to weigh the costs and
> benefits of the transaction. To assess whether the appropriation of attention
> is net-positive, it's useful to distinguish between *extractive* and
> *non-extractive* contributions. Extractive contributions are those where the
> marginal cost of reviewing and merging that contribution is greater than the
> marginal benefit to the project's producers. In the case of a code
> contribution, it might be a pull request that's too complex or unwieldy to
> review, given the potential upside." -- Nadia Eghbal

Prior to the advent of LLMs, open source project maintainers would often review
any and all changes sent to the project simply because posting a change for
review was a sign of interest from a potential long-term contributor. While new
tools enable more development, it shifts effort from the implementor to the
reviewer, and our policy exists to ensure that we value and do not squander
maintainer time.

## Handling Violations

If a maintainer judges that a contribution doesn't comply with this policy, they
should paste the following response to request changes:

> This PR doesn't appear to comply with our policy on tool-generated content,
> and requires additional justification for why it is valuable enough to the
> project for us to review it. Please see our AI/LLM tool policy:
> https://github.com/timlinux/tuinix/blob/main/.github/AI_POLICY.md

The best ways to make a change less extractive and more valuable are to reduce
its size or complexity or to increase its usefulness to the community. These
factors are impossible to weigh objectively, and our project policy leaves this
determination up to the maintainers of the project, i.e. those who are doing the
work of sustaining the project.

If or when it becomes clear that a GitHub issue or PR is off-track and not moving
in the right direction, maintainers should apply the `extractive` label to help
other reviewers prioritize their review time.

If a contributor fails to make their change meaningfully less extractive,
maintainers may lock the conversation and/or close the pull request or issue.

## Copyright

Artificial intelligence systems raise many questions around copyright that have
yet to be answered. Our policy on AI tools is similar to our copyright policy:
Contributors are responsible for ensuring that they have the right to contribute
code under the terms of our license, typically meaning that either they, their
employer, or their collaborators hold the copyright. Using AI tools to regenerate
copyrighted material does not remove the copyright, and contributors are
responsible for ensuring that such material does not appear in their
contributions. Contributions found to violate this policy will be removed just
like any other offending contribution.

## Credits

This document is adapted from the
[LLVM "AI Tool Use Policy"](https://github.com/llvm/llvm-project/blob/main/llvm/docs/AIToolPolicy.md),
with due credits to its original authors: Reid Kleckner, Hubert Tong, and
"maflcko". It was brought to our attention via the
[QGIS project's adaptation](https://github.com/qgis/QGIS-Documentation/pull/10714)
by Even Rouault.
