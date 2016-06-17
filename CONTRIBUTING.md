# Feature Development:
Developing for cerner_splunk_ingredient should follow these guidelines for submitting issues and pull requests.

### Submitting Issues
Issues pertaining to cerner_splunk_ingredient should be submitted to Github's issue tracker.
1. Issues will be triaged and marked with an appropriate label (e.g. bug, enhancement, question).
  - A corresponding internal JIRA may be logged if there is a desire for internal discussion or code review.
- The issue should be worked in a branch outside of the Cerner repo.
- The issue will be marked for the next milestone following a pull request.

### Pull Requests
Pull requests for changes should be compared against the 'stable' branch.
1. Your branch should use as few logical commits as possible with descriptive commit messages.
  - _Note: these commits should **not** reference any issues, that will be done in the merge commit._
- Your pull request should reference the issue it is related to.
- The pull request is collectively reviewed and commented on, and must get two or more +1's, from reviewers and at least one maintainer of the repo.
  - Any raised comments must be addressed and will be re-reviewed.
- Once the pull request is approved, the changes will be merged by a maintainer.
    - This is done manually, not by using the Github button, so that the fix version of metadata.rb can be incremented in the merge. ([Example](https://github.com/cerner/cerner_splunk/issues/41#issuecomment-70569000))
    - The merge commit text should reference the issue and the pull request so that both are closed when the merge is pushed.

# Release Process:
1. An issue is made to release a new version
    - The issue will summarize what was changed since the last milestone, and propose the commit to tag and its description.
    - The issue will be labeled "release"
- The issue is reviewed, and must get two or more +1s from reviewers and maintainers.
- An annotated tag is created with the reviewed release text.
    - Master is set to the annotated tag.
- The cookbook is released to Supermarket
- Cleanup
    - The issue and existing milestone is closed
    - A new milestone is created for the next version
