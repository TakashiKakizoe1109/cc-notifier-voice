## Summary

<!-- What does this PR do? Why is it needed? -->

## Test plan

<!-- How did you verify the changes? -->

- [ ] `bash -n` passes on all modified `.sh` files
- [ ] Tested on macOS (notification + TTS)
- [ ] EN/JA documentation updated if user-facing behavior changed

## Checklist

- [ ] Follows [Conventional Commits](https://www.conventionalcommits.org/) message format
- [ ] No `eval` or unquoted command expansion for user input
- [ ] Arguments passed as arrays (no word-splitting)
- [ ] Version numbers NOT bumped (handled during release)
