"""把资源包里的文案和头像“编译进”dylib，这样只注入一个 Guagua.dylib 也能完整显示中文。

生成 src/Core/GuaguaEmbedded.h / .m
"""
import base64
import pathlib
import re

ROOT = pathlib.Path(r"C:\Users\Administrator\Desktop\GuaguaAssistant")
BUNDLE = ROOT / "layout/Library/Application Support/Guagua/Guagua.bundle"
OUT_H = ROOT / "src/Core/GuaguaEmbedded.h"
OUT_M = ROOT / "src/Core/GuaguaEmbedded.m"

PAIR = re.compile(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')


def unescape(value: str) -> str:
    out, i = [], 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            out.append({"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}.get(nxt, nxt))
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def c_string(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def load(lang: str) -> dict:
    path = BUNDLE / f"{lang}.lproj" / "Localizable.strings"
    if not path.is_file():
        return {}
    return {k: unescape(v) for k, v in PAIR.findall(path.read_text(encoding="utf-8"))}


def main():
    tables = {lang: load(lang) for lang in ("zh_CN", "zh-Hant", "en")}
    lines = []
    for lang, table in tables.items():
        ident = lang.replace("-", "_")
        lines.append(f"static NSDictionary* GuaguaTable_{ident}(void) {{")
        lines.append("    static NSDictionary* table;")
        lines.append("    static dispatch_once_t once;")
        lines.append("    dispatch_once(&once, ^{")
        lines.append(f"        table = @{{")
        for key, value in sorted(table.items()):
            lines.append(f'            @"{c_string(key)}": @"{c_string(value)}",')
        lines.append("        };")
        lines.append("    });")
        lines.append("    return table;")
        lines.append("}")
        lines.append("")

    avatar = (BUNDLE / "samuel.png").read_bytes()
    b64 = base64.b64encode(avatar).decode()

    header = """//
//  GuaguaEmbedded.h
//  呱呱助手 (Guagua Assistant)
//
//  内嵌资源：资源包没被注入器装进去时，UI 仍然有完整中文文案 + 开发者头像。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 按系统语言优先查内嵌字符串表；查不到返回 nil（调用方再回落到 key）。
NSString* _Nullable GuaguaEmbeddedString(NSString* key);

/// 内嵌的开发者头像（Guagua.bundle/samuel.png 的 base64 版本）。
UIImage* _Nullable GuaguaEmbeddedAvatar(void);

NS_ASSUME_NONNULL_END
"""

    source = [
        "//",
        "//  GuaguaEmbedded.m",
        "//  呱呱助手 (Guagua Assistant)",
        "//",
        "//  由 tools/gen_embedded.py 生成，不要手改。",
        "//",
        "",
        '#import "Core/GuaguaEmbedded.h"',
        "",
        *lines,
        "static NSString* GuaguaLanguageCode(void) {",
        "    for (NSString* preferred in [NSLocale preferredLanguages]) {",
        "        NSString* lower = preferred.lowercaseString;",
        '        if ([lower hasPrefix:@"zh-hant"] || [lower hasPrefix:@"zh-tw"] ||',
        '            [lower hasPrefix:@"zh-hk"]) {',
        '            return @"zh-Hant";',
        "        }",
        '        if ([lower hasPrefix:@"zh"]) {',
        '            return @"zh_CN";',
        "        }",
        "        break;",
        "    }",
        '    return @"en";',
        "}",
        "",
        "NSString* GuaguaEmbeddedString(NSString* key) {",
        "    if (key.length == 0) {",
        "        return nil;",
        "    }",
        '    NSString* lang = GuaguaLanguageCode();',
        '    if ([lang isEqualToString:@"zh_CN"]) {',
        "        NSString* value = GuaguaTable_zh_CN()[key];",
        "        if (value.length) {",
        "            return value;",
        "        }",
        "    }",
        '    if ([lang isEqualToString:@"zh-Hant"]) {',
        "        NSString* value = GuaguaTable_zh_Hant()[key];",
        "        if (value.length) {",
        "            return value;",
        "        }",
        "    }",
        "    NSString* value = GuaguaTable_en()[key];",
        "    if (value.length) {",
        "        return value;",
        "    }",
        "    return GuaguaTable_zh_CN()[key];",
        "}",
        "",
        f'static NSString* const kGuaguaAvatarBase64 = @"{b64}";',
        "",
        "UIImage* GuaguaEmbeddedAvatar(void) {",
        "    static UIImage* image;",
        "    static dispatch_once_t once;",
        "    dispatch_once(&once, ^{",
        "        NSData* data = [[NSData alloc] initWithBase64EncodedString:kGuaguaAvatarBase64",
        "                                                          options:0];",
        "        if (data.length) {",
        "            image = [UIImage imageWithData:data];",
        "        }",
        "    });",
        "    return image;",
        "}",
        "",
    ]

    OUT_H.write_text(header, encoding="utf-8")
    OUT_M.write_text("\n".join(source), encoding="utf-8")
    print(f"generated: {OUT_H.name} {OUT_H.stat().st_size} B, {OUT_M.name} {OUT_M.stat().st_size} B")
    for lang, table in tables.items():
        print(f"  {lang}: {len(table)} keys")
    print(f"  avatar: {len(avatar)} B -> base64 {len(b64)} chars")


if __name__ == "__main__":
    main()
