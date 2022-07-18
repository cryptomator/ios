#!/bin/sh
#
# Based on https://merowing.info/2021/01/improve-build-times-by-extracting-3rd-party-tooling-to-processing-script./

cd "$(dirname "$0")/.."

if [[ "$1" == "--staged" ]]; then
  staged_mode=true
  echo "Running in --staged mode"
else
  echo "Running in full mode"
fi

final_status=0

function process_output() {
  printf '\n# Running %s\n' "$1"
  local start=$(date +%s)
  local output=$(eval "$2" 2>&1)
  local cleaned_output=$(echo "$output" | sed '/.*xcodebuild.*/d')
  if [[ ! -z "$cleaned_output" ]]; then
    printf -- '---\n%s\n---\n' "$cleaned_output"
    final_status=1
  fi
  local end=$(date +%s)
  printf 'Execution time was %s seconds.\n' "$((end - start))"
}

if [ "$staged_mode" = true ]; then
  process_output "SwiftFormat" "python3 ./Scripts/git-format-staged.py -f 'swiftformat stdin --stdinpath \"{}\" --quiet' '*.swift'"
  process_output "SwiftLint" "python3 ./Scripts/git-format-staged.py --no-write -f 'swiftlint --use-stdin --quiet >&2' '*.swift'"
  if [[ "$final_status" -gt 0 ]]; then
    printf '\nChanges werde made or are required. Please review the output above for further details.\n'
  fi
else
  process_output "SwiftFormat" "swiftformat --lint --quiet ."
  process_output "SwiftLint" "swiftlint --quiet ."
  if [[ "$final_status" -gt 0 ]]; then
    printf '\nChanges are required. Please review the output above for further details.\n'
  fi
fi

exit $final_status
