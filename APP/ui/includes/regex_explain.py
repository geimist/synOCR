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

    def parse_list(self):
        out = []
        while not self.at_end():
            item = self.parse_one()
            if item is None:
                raise ValueError("parse")
            if isinstance(item, list):
                out.extend(item)
            else:
                out.append(item)
        return out

    def parse_one(self):
        group = self.parse_paren_group()
        if group is not None:
            return group
        return self.parse_atom()

    def parse_paren_group(self):
        branch_reset = False
        open_pos = -1
        inner_start = -1

        if self.try_take("(?|"):
            branch_reset = True
            open_pos = self.pos - 3
            inner_start = self.pos
        elif self.try_take("(?:"):
            open_pos = self.pos - 3
            inner_start = self.pos
        elif self.pos < len(self.pattern) and self.pattern[self.pos] == "(":
            rest = self.pattern[self.pos :]
            if rest.startswith("(?") and not rest.startswith("(?|") and not rest.startswith("(?:"):
                return None
            open_pos = self.pos
            self.pos += 1
            inner_start = self.pos
        else:
            return None

        close = find_balanced_close(self.pattern, open_pos)
        if close < 0:
            raise ValueError("parse")
        inner = self.pattern[inner_start:close]
        self.pos = close + 1
        optional = self.try_take("?")

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
            if len(subs) == 1:
                item = subs[0]
            elif len(subs) == 0:
                item = {"kind": "group", "items": []}
            else:
                return subs

        if optional:
            item["optional"] = True
        return item

    def parse_atom(self):
        if self.try_take("\\K"):
            return {"kind": "keep"}

        for esc, kind in (("\\n", "newline"), ("\\r", "cr"), ("\\t", "tab")):
            if self.try_take(esc):
                return {"kind": "escape", "escapeKind": kind}

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
        return {
            "kind": "context",
            "lookKind": kind_map.get(m.group(1), "after"),
            "text": unesc_pcre(inner),
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
        if not kind:
            return None

        item = {"kind": "class", "classKind": kind}
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
            item["classQuant"] = "plus"
            item["optional"] = True
            return item
        raise ValueError("parse")

    def try_literal(self):
        start = self.pos
        while not self.at_end():
            if self.is_atom_start():
                break
            if self.pattern[self.pos] == "\\":
                if self.pos + 1 < len(self.pattern):
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
        checks = (
            "(?|",
            "(?:",
            "(?",
            "(",
            "\\n",
            "\\r",
            "\\t",
            "\\b",
            "\\s*",
            "\\s+",
            "\\s?",
            "\\d",
            ".*?",
            ".*",
            ".+?",
            ".+",
            ".?",
            ".",
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
                items.append(one)
                pos += sub.pos
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
            items.append({"kind": "unknown", "raw": raw})
            pos = end
    return items


_DEBRIS_RE = re.compile(r"[?|():\\]")


def is_low_quality(items, pattern):
    if not items:
        return True

    unknown = sum(1 for i in items if i.get("kind") == "unknown")
    if unknown > 2:
        return True
    if unknown and unknown / len(items) > 0.2:
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

    return {"ok": True, "items": items}


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
