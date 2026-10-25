# Turns a Grype SARIF report into a markdown table for the job summary: one row per
# vulnerability with a CVSS score of 7.0 or more, highest first. Used by images.yml.
.runs[0] as $r
| ($r.tool.driver.rules | map({key: .id, value: (.properties["security-severity"] | tonumber? // 0)}) | from_entries) as $score
| [$r.results[] | {id: .ruleId, score: $score[.ruleId],
    pkg: ((.message.text | capture("package: (?<p>[^ ,]+), version (?<v>[^ ]+)") | "\(.p) \(.v)") // ""),
    at: ((.message.text | capture(" at: (?<a>.+)$").a) // "")}]
| map(select(.score >= 7)) | unique_by(.id) | sort_by(-.score)
| if length == 0 then "None." else
    ("| Vulnerability | Score | Package | Where |", "|---|---|---|---|",
     (.[] | "| \(.id) | \(.score) | \(.pkg) | \(.at) |"))
  end
