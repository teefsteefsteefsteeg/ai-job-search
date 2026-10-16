#!/bin/bash
# usage: gba_gen.sh <dir/state> <out> <aspect> <facing text> <ref1> [ref2...]
s=$1; out=$2; asp=$3; face=$4; shift 4
T=/home/user/ai-job-search/island-keeper/Tools/art
mkdir -p .prompts-or; f=.prompts-or/${s/\//_}.txt
{ cat $T/noguide_note.txt $T/gba_style.txt $T/gba_identity.txt; echo; echo "$face"; echo; cat prompts/$s.txt; } > $f
refs=(); for r in "$@"; do refs+=(--ref "$r"); done
/tmp/claude-0/-home-user-ai-job-search/77487347-3aba-5fb7-834c-234f567d785e/scratchpad/ext/sprite-gen/.venv/bin/python $T/openrouter_gen.py --prompt-file $f "${refs[@]}" --aspect $asp --out $out
