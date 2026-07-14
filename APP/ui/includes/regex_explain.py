#!/usr/bin/env python3
# Best-effort PCRE pattern tokenizer for human-readable explanations (synOCR).
# Reads JSON from stdin, writes JSON to stdout. Uses the venv `regex` package.
import json
import re
import sys

try:
    import regex
except ImportError:
    print(json.dumps({"ok": False, "error": "venv"}))
    sys.exit(1)

def unesc_pcre(s):
    return re.sub(r"\\(.)", r"\1", s)


def find_balanced_close(s, open_pos):
    depth = 1
    i = open_pos + 1
    while i < len(s):
        if s[i] == "\\":
            i += 2
            continue
        if s.startswith("(?", i):
            close = find_balanced_close(s, i)
            if close < 0:
                return -1
            i = close + 1
            continue
        if s[i] == "(":
            close = find_balanced_close(s, i)
            if close < 0:
                return -1
            i = close + 1
            continue
        if s[i] == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def has_top_level_pipe(s):
    depth = 0
    i = 0
    while i < len(s):
        if s[i] == "\\":
            i += 2
            continue
        if s.startswith("(?:", i) or s.startswith("(?|", i):
            depth += 1
            i += 3
            continue
        if s[i] == "(":
            depth += 1
            i += 1
            continue
        if s[i] == ")":
            depth -= 1
            i += 1
            continue
        if s[i] == "|" and depth == 0:
            return True
        i += 1
    return False


def split_top_level_alt(s):
    parts = []
    cur = []
    depth = 0
    i = 0
    while i < len(s):
        if s[i] == "\\":
            if i + 1 < len(s):
                cur.append(s[i : i + 2])
                i += 2
                continue
        if s.startswith("(?:", i) or s.startswith("(?|", i):
            depth += 1
            cur.append(s[i : i + 3])
            i += 3
            continue
        if s[i] == "(":
            depth += 1
            cur.append("(")
            i += 1
            continue
        if s[i] == ")":
            depth -= 1
            cur.append(")")
            i += 1
            continue
        if s[i] == "|" and depth == 0:
            parts.append("".join(cur))
            cur = []
            i += 1
            continue
        cur.append(s[i])
        i += 1
    parts.append("".join(cur))
    return parts


_BRACKET_SHORTHANDS = {
    "w": "word", "W": "non_word",
    "d": "digit", "D": "non_digit",
    "s": "space", "S": "non_space",
    "h": "h_space", "v": "v_space",
    "n": "newline", "r": "cr", "t": "tab",
}


def parse_bracket_parts(raw):
    parts = []
    i = 0
    n = len(raw)
    while i < n:
        if raw[i] == "\\" and i + 1 < n:
            c = raw[i + 1]
            if c in _BRACKET_SHORTHANDS:
                parts.append({"kind": "shorthand", "escape": _BRACKET_SHORTHANDS[c]})
            else:
                parts.append({"kind": "char", "char": c})
            i += 2
            continue
        if i + 2 < n and raw[i + 1] == "-" and raw[i + 2] != "]":
            parts.append({"kind": "range", "from": raw[i], "to": raw[i + 2]})
            i += 3
            continue
        parts.append({"kind": "char", "char": raw[i]})
        i += 1
    return parts


class PatternTokenizer:
    def __init__(self, pattern, list_mode="match"):
        self.pattern = pattern
        self.pos = 0
        self.list_mode = list_mode

    def at_end(self):
        return self.pos >= len(self.pattern)

    def try_take(self, lit):
        if self.pattern[self.pos : self.pos + len(lit)] != lit:
            return False
        self.pos += len(lit)
        return True

    def _set_span(self, item, start, end):
        item["start"] = start
        item["length"] = end - start
        item["span"] = self.pattern[start:end]

    def parse_list(self):
        out = []
        while not self.at_end():
            start = self.pos
            item = self.parse_one()
            if item is None:
                raise ValueError("parse")
            end = self.pos
            if isinstance(item, list):
                out.extend(item)
            else:
                self._set_span(item, start, end)
                out.append(item)
        return out

    def parse_one(self):
        group = self.parse_paren_group()
        if group is not None:
            return group
        return self.parse_atom()

    def try_inline_flags(self, open_pos):
        rest = self.pattern[self.pos :]
        if not rest.startswith("?"):
            return None
        if re.match(r"^\?(?:\||:|[<=!])", rest):
            return None
        m = re.match(r"^\?([imsxU\-]+)(:)?", rest)
        if not m:
            return None
        flags_str = m.group(1)
        has_colon = bool(m.group(2))
        self.pos += len(m.group(0))
        if has_colon:
            close = find_balanced_close(self.pattern, open_pos)
            if close < 0:
                raise ValueError("parse")
            inner = self.pattern[self.pos : close]
            self.pos = close + 1
            sub = PatternTokenizer(inner, self.list_mode)
            items = sub.parse_list()
            if not sub.at_end():
                raise ValueError("parse")
            return {"kind": "flags_group", "flags": flags_str, "items": items}
        if not self.try_take(")"):
            raise ValueError("parse")
        return {"kind": "flags", "flags": flags_str, "scope": "rest"}

    def parse_paren_group(self):
        branch_reset = False
        captured = False
        open_pos = -1
        inner_start = -1

        if self.try_take("(?|"):
            branch_reset = True
            open_pos = self.pos - 3
            inner_start = self.pos
        elif self.try_take("(?>"):
            open_pos = self.pos - 3
            inner_start = self.pos
            close = find_balanced_close(self.pattern, open_pos)
            if close < 0:
                raise ValueError("parse")
            inner = self.pattern[inner_start:close]
            self.pos = close + 1
            sub = PatternTokenizer(inner, self.list_mode)
            inner_items = sub.parse_list()
            if not sub.at_end():
                raise ValueError("parse")
            item = {"kind": "atomic", "items": inner_items}
            self._apply_repeat_quantifier(item)
            return item
        elif self.try_take("(?:"):
            open_pos = self.pos - 3
            inner_start = self.pos
        elif self.pos < len(self.pattern) and self.pattern[self.pos] == "(":
            open_pos = self.pos
            self.pos += 1
            flags_item = self.try_inline_flags(open_pos)
            if flags_item is not None:
                return flags_item
            rest = self.pattern[self.pos :]
            if re.match(r"^\?(<=|<!|!|=)", rest):
                self.pos = open_pos
                return None
            inner_start = self.pos
            captured = True
        else:
            return None

        close = find_balanced_close(self.pattern, open_pos)
        if close < 0:
            raise ValueError("parse")
        inner = self.pattern[inner_start:close]
        self.pos = close + 1

        if branch_reset:
            sub = PatternTokenizer(inner, self.list_mode)
            inner_items = sub.parse_list()
            if not sub.at_end():
                raise ValueError("parse")
            item = {"kind": "branch_reset", "items": inner_items}
        elif has_top_level_pipe(inner):
            branches = []
            for part in split_top_level_alt(inner):
                sub = PatternTokenizer(part, self.list_mode)
                branch_items = sub.parse_list()
                if not sub.at_end():
                    raise ValueError("parse")
                branches.append(branch_items)
            item = {"kind": "alt", "branches": branches}
        else:
            sub = PatternTokenizer(inner, self.list_mode)
            subs = sub.parse_list()
            if not sub.at_end():
                raise ValueError("parse")
            if captured:
                item = {"kind": "group", "captured": True, "items": subs}
            elif len(subs) == 1:
                item = subs[0]
            elif len(subs) == 0:
                item = {"kind": "group", "items": []}
            else:
                item = {"kind": "group", "items": subs}

        self._apply_repeat_quantifier(item)
        return item

    def _apply_repeat_quantifier(self, item):
        if self.try_take("*"):
            item["repeat"] = "star"
        elif self.try_take("+"):
            item["repeat"] = "plus"
        elif self.try_take("?"):
            item["optional"] = True
        elif self.try_take("{"):
            body = ""
            while not self.at_end() and self.pattern[self.pos] != "}":
                body += self.pattern[self.pos]
                self.pos += 1
            if not self.try_take("}"):
                raise ValueError("parse")
            parts = body.split(",")
            item["repeat"] = "range"
            item["n"] = parts[0] or "0"
            item["m"] = parts[1] if len(parts) > 1 else ""

    def apply_class_quantifier(self, item):
        if self.try_take("{"):
            body = ""
            while not self.at_end() and self.pattern[self.pos] != "}":
                body += self.pattern[self.pos]
                self.pos += 1
            if not self.try_take("}"):
                raise ValueError("parse")
            parts = body.split(",")
            if len(parts) > 1:
                item["classQuant"] = "range"
                item["n"] = parts[0] or "0"
                item["m"] = parts[1] if len(parts) > 1 else ""
            else:
                item["classQuant"] = "fixed"
                item["n"] = parts[0] or "0"
                item["m"] = ""
            return item
        if self.try_take("*"):
            item["classQuant"] = "star"
            return item
        if self.try_take("+"):
            item["classQuant"] = "plus"
            return item
        if self.try_take("?"):
            item["optional"] = True
            return item
        return item

    def parse_atom(self):
        if self.try_take("\\K"):
            return {"kind": "keep"}

        backref = self.try_backreference()
        if backref:
            return backref

        for esc, kind in (
            ("\\w", "word"),
            ("\\W", "non_word"),
            ("\\D", "non_digit"),
            ("\\S", "non_space"),
            ("\\R", "line_break"),
            ("\\N", "not_newline"),
            ("\\n", "newline"),
            ("\\r", "cr"),
            ("\\t", "tab"),
        ):
            if self.try_take(esc):
                item = {"kind": "escape", "escapeKind": kind}
                if esc in ("\\w", "\\W", "\\D", "\\S"):
                    if self.pattern[self.pos : self.pos + 1] in "*+?{":
                        return self.apply_class_quantifier(item)
                return item

        if self.try_take("\\b"):
            return {"kind": "anchor", "anchorKind": "word"}

        if self.try_take("^"):
            return {"kind": "anchor", "anchorKind": "start"}

        if self.try_take("$"):
            return {"kind": "anchor", "anchorKind": "end"}

        if self.try_take(".*?"):
            return {"kind": "variable", "varKind": "any"}

        if self.try_take(".*"):
            return {"kind": "variable", "varKind": "greedy"}

        if self.try_take(".+?"):
            return {"kind": "char_plus", "lazy": True}

        if self.try_take(".+"):
            return {"kind": "char_plus"}

        if self.try_take(".?"):
            return {"kind": "char_optional"}

        if self.try_take("."):
            return {"kind": "char_any"}

        if self.try_take("\\s*"):
            return {"kind": "variable", "varKind": "ws", "varQuant": "star"}

        if self.try_take("\\s+"):
            return {"kind": "variable", "varKind": "ws", "varQuant": "plus"}

        if self.try_take("\\s?"):
            return {"kind": "variable", "varKind": "ws", "optional": True}

        if self.try_take("\\s"):
            return {"kind": "variable", "varKind": "ws"}

        look = self.try_lookaround()
        if look:
            return look

        cls = self.try_class()
        if cls:
            return cls

        lit = self.try_literal()
        if lit:
            return lit

        return None

    def try_backreference(self):
        rest = self.pattern[self.pos :]
        m = re.match(r"^\\g(?:<([^>]+)>|'([^']+)')", rest)
        if m:
            self.pos += m.end()
            return {"kind": "backref", "ref": m.group(1) or m.group(2), "style": "g"}
        m = re.match(r"^\\k(?:<([^>]+)>|'([^']+)')", rest)
        if m:
            self.pos += m.end()
            return {"kind": "backref", "ref": m.group(1) or m.group(2), "style": "k"}
        m = re.match(r"^\\([1-9]\d*)", rest)
        if m:
            self.pos += m.end()
            return {"kind": "backref", "ref": m.group(1), "style": "num"}
        return None

    def try_lookaround(self):
        rest = self.pattern[self.pos :]
        m = re.match(r"^\(\?(<=|<!|!|=)", rest)
        if not m:
            return None
        kind_map = {"<=": "before", "<!": "notBefore", "!": "notAfter", "=": "after"}
        open_len = 3 + (len(m.group(1)) - 1)
        close = find_balanced_close(self.pattern, self.pos)
        if close < 0:
            return None
        inner = self.pattern[self.pos + open_len : close]
        self.pos = close + 1
        item = {
            "kind": "context",
            "lookKind": kind_map.get(m.group(1), "after"),
            "text": unesc_pcre(inner),
        }
        try:
            sub = PatternTokenizer(inner, self.list_mode)
            inner_items = sub.parse_list()
            if sub.at_end() and inner_items:
                item["items"] = inner_items
        except ValueError:
            pass
        return item

    def try_parse_bracket_class(self):
        if self.pos >= len(self.pattern) or self.pattern[self.pos] != "[":
            return None
        negated = False
        i = self.pos + 1
        if i < len(self.pattern) and self.pattern[i] == "^":
            negated = True
            i += 1
        raw_parts = []
        while i < len(self.pattern):
            if self.pattern[i] == "\\":
                if i + 1 < len(self.pattern):
                    raw_parts.append(self.pattern[i : i + 2])
                    i += 2
                    continue
                break
            if self.pattern[i] == "]" and raw_parts:
                i += 1
                break
            if self.pattern[i] == "]" and not raw_parts:
                raw_parts.append("]")
                i += 1
                break
            raw_parts.append(self.pattern[i])
            i += 1
        else:
            return None
        raw = "".join(raw_parts)
        self.pos = i
        return {
            "kind": "class_generic",
            "raw": raw,
            "negated": negated,
            "parts": parse_bracket_parts(raw),
        }

    def try_class(self):
        kind = ""
        if self.try_take("\\d"):
            kind = "digits"
        elif self.try_take("[A-Za-z0-9]"):
            kind = "alnum"
        elif self.try_take("[A-Za-z]"):
            kind = "letters"
        elif self.try_take("[^A-Za-z0-9]"):
            kind = "special"
        if kind:
            item = {"kind": "class", "classKind": kind}
            return self.apply_class_quantifier(item)

        generic = self.try_parse_bracket_class()
        if generic:
            return self.apply_class_quantifier(generic)

        return None

    def try_literal(self):
        start = self.pos
        while not self.at_end():
            if self.is_atom_start():
                break
            if self.pattern[self.pos] == "\\":
                if self.pos + 1 < len(self.pattern):
                    nxt = self.pattern[self.pos + 1]
                    if nxt in "wWdDsSnrtRNK":
                        break
                    if nxt.isdigit() and nxt != "0":
                        break
                    if nxt in "gk":
                        break
                    self.pos += 2
                    continue
                break
            self.pos += 1
        if self.pos == start:
            return None
        raw = self.pattern[start : self.pos]
        text = unesc_pcre(raw.replace("\\s+", " "))
        return {"kind": "fixed", "text": text, "wsFlex": bool(re.search(r"\\s\+", raw))}

    def is_atom_start(self):
        s = self.pattern[self.pos :]
        if re.match(r"^\\[1-9]\d*", s):
            return True
        if s.startswith("\\g") or s.startswith("\\k"):
            return True
        checks = (
            "(?|",
            "(?:",
            "(?>",
            "(?",
            "(",
            "\\w",
            "\\W",
            "\\D",
            "\\S",
            "\\R",
            "\\N",
            "\\n",
            "\\r",
            "\\t",
            "\\b",
            "\\s*",
            "\\s+",
            "\\s?",
            "\\s",
            "\\d",
            ".*?",
            ".*",
            ".+?",
            ".+",
            ".?",
            ".",
            "[",
            "[A-Za-z0-9]",
            "[A-Za-z]",
            "[^A-Za-z0-9]",
            "\\K",
            "^",
            "$",
        )
        for lit in checks:
            if s.startswith(lit):
                return True
        return False


def tokenize_pattern(pattern):
    p = PatternTokenizer(pattern, "match")
    items = p.parse_list()
    if not p.at_end():
        raise ValueError("parse")
    return items


def tokenize_best_effort(pattern):
    items = []
    pos = 0
    while pos < len(pattern):
        try:
            sub = PatternTokenizer(pattern[pos:], "match")
            one = sub.parse_one()
            if one is None:
                raise ValueError("parse")
            if isinstance(one, list):
                items.extend(one)
                pos += sub.pos
            else:
                end = pos + sub.pos
                one["start"] = pos
                one["length"] = sub.pos
                one["span"] = pattern[pos:end]
                items.append(one)
                pos = end
        except ValueError:
            end = pos + 1
            while end < len(pattern):
                try:
                    sub = PatternTokenizer(pattern[end:], "match")
                    sub.parse_one()
                    break
                except ValueError:
                    end += 1
            raw = pattern[pos:end]
            items.append({"kind": "unknown", "raw": raw, "start": pos, "length": end - pos, "span": raw})
            pos = end
    return items


_DEBRIS_RE = re.compile(r"[?|():\\]")


def check_redos_warnings(pattern):
    warnings = []
    if re.search(r"\([^)]*(\.\*|\.\+|\.\+?)[^)]*\)[+*?]", pattern):
        warnings.append("redos_nested_quant")
    if re.search(r"\([^)]*[+*?][^)]*\)[+*]", pattern):
        warnings.append("redos_nested_quant")
    if re.search(r"(\.\*|\.\+).{0,40}(\.\*|\.\+)", pattern):
        warnings.append("redos_overlapping_wildcard")
    return list(dict.fromkeys(warnings))


def annotate_extract_roles(items):
    phase = "before"
    for item in items:
        if item.get("kind") == "keep":
            phase = "value"
            continue
        if phase == "before":
            item["extractRole"] = "anchor"
        elif phase == "value":
            if item.get("kind") == "context" and item.get("lookKind") in ("after", "notAfter"):
                item["extractRole"] = "anchor"
                phase = "after"
            else:
                item["extractRole"] = "value"
        else:
            item["extractRole"] = "anchor"


def is_low_quality(items, pattern):
    if not items:
        return True

    unknown = sum(1 for i in items if i.get("kind") == "unknown")
    if unknown > 3 and len(items) > 8:
        return True
    if unknown and unknown / len(items) > 0.33:
        return True

    debris = 0
    for item in items:
        if item.get("kind") != "fixed":
            continue
        text = item.get("text", "")
        if len(text) <= 5 and _DEBRIS_RE.search(text):
            debris += 1
    if debris >= 2:
        return True

    if len(items) > max(14, len(pattern) // 2):
        return True

    return False


def explain_pattern(pattern, multiline=False, casesensitive=False):
    if not pattern:
        return {"ok": True, "items": []}

    flags = 0
    if not casesensitive:
        flags |= regex.IGNORECASE
    if multiline:
        flags |= regex.MULTILINE

    try:
        regex.compile(pattern, flags)
    except regex.error:
        return {"ok": False, "error": "syntax"}

    try:
        items = tokenize_pattern(pattern)
    except ValueError:
        items = tokenize_best_effort(pattern)

    if is_low_quality(items, pattern):
        return {"ok": True, "items": []}

    if "\\K" in pattern:
        annotate_extract_roles(items)

    result = {"ok": True, "items": items}
    warnings = check_redos_warnings(pattern)
    if warnings:
        result["warnings"] = warnings
    return result


def main():
    try:
        req = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        print(json.dumps({"ok": False, "error": "syntax"}))
        return

    pattern = req.get("pattern", "")
    multiline = bool(req.get("multiline", False))
    casesensitive = bool(req.get("casesensitive", False))
    result = explain_pattern(pattern, multiline, casesensitive)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
