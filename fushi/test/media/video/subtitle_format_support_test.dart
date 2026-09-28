// BUG-2748：外挂字幕格式支持——SRT / VTT 逐行扫描的回归，外加 SAMI / TTML / SBV
// 三种新格式与「扩展名唯一真相源」的路由契约。
import 'package:flutter_test/flutter_test.dart';
import 'package:fushi_audio/fushi_audio.dart';
import 'package:fushi_engine/media/video/video_sidecar.dart';
import 'package:fushi_engine/media/video/video_subtitle_source.dart';

List<String> _render(List<AudioCue> cues) => <String>[
      for (final AudioCue c in cues) '${c.startMs}-${c.endMs} ${c.text}',
    ];

List<String> _vtt(String s) =>
    _render(VttParser.parseString(content: s, bookKey: 'b'));
List<String> _srt(String s) =>
    _render(SrtParser.parseString(content: s, bookKey: 'b'));

void main() {
  group('VTT 逐行扫描（BUG-2748）', () {
    test('仅含空白的分隔行不再把整份文件并进 WEBVTT 头（原 0 条 cue）', () {
      expect(
        _vtt('WEBVTT\n \n00:00:01.000 --> 00:00:02.000\nA\n \t\n'
            '00:00:03.000 --> 00:00:04.000\nB\n'),
        <String>['1000-2000 A', '3000-4000 B'],
      );
    });

    test('头部与首条 cue 之间缺空行不丢首条', () {
      expect(
        _vtt('WEBVTT\n00:00:01.000 --> 00:00:02.000\nA\n\n'
            '00:00:03.000 --> 00:00:04.000\nB\n'),
        <String>['1000-2000 A', '3000-4000 B'],
      );
    });

    test('NOTE / STYLE / REGION / cue ID 被跳过，cue 设置被忽略', () {
      expect(
        _vtt('WEBVTT\nKind: captions\n\nSTYLE\n::cue { color: red }\n\n'
            'NOTE 这是注释\n\nREGION\nid:r1\n\nintro\n'
            '00:01.500 --> 00:02.000 align:start position:10%\n'
            '<v Roger>こん<00:00:01.800><c>にちは</c>\n'),
        <String>['1500-2000 こんにちは'],
      );
    });

    test('字符实体解码（剥标签之后）', () {
      expect(
        _vtt('WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n'
            'Tom &amp; Jerry &lt;b&gt; &#x3042;&#12354;\n'),
        <String>['1000-2000 Tom & Jerry <b> ああ'],
      );
    });

    test('无毫秒 / 超 3 位小数的时间码可解析', () {
      expect(
        _vtt('WEBVTT\n\n00:00:01 --> 00:00:02.12345\nA\n'),
        <String>['1000-2123 A'],
      );
    });

    test('CRLF + BOM', () {
      expect(
        _vtt('﻿WEBVTT\r\n\r\n00:00:01.000 --> 00:00:02.000\r\nA\r\nB\r\n'),
        <String>['1000-2000 A B'],
      );
    });
  });

  group('SRT 逐行扫描（BUG-2748）', () {
    test('空白分隔行不再把后续 cue 的序号与时间码拼进正文', () {
      expect(
        _srt('1\n00:00:01,000 --> 00:00:02,000\nA\n  \n'
            '2\n00:00:03,000 --> 00:00:04,000\nB\n'),
        <String>['1000-2000 A', '3000-4000 B'],
      );
    });

    test('没有序号行的单行 cue 不再被丢弃', () {
      expect(
        _srt('00:00:01,000 --> 00:00:02,000\nA\n\n'
            '00:00:03,000 --> 00:00:04,000\nB\n'),
        <String>['1000-2000 A', '3000-4000 B'],
      );
    });

    test('结束时间后的坐标被忽略', () {
      expect(
        _srt('1\n00:00:01,000 --> 00:00:02,000  X1:100 X2:200 Y1:10 Y2:20\n'
            '<i>A</i>\n'),
        <String>['1000-2000 A'],
      );
    });

    test('正文里的纯数字行保留（只有 cue 外的序号行被跳过）', () {
      expect(
        _srt('1\n00:00:01,000 --> 00:00:02,000\n2024\n'),
        <String>['1000-2000 2024'],
      );
    });
  });

  group('SAMI', () {
    const String sami = '''
<SAMI><HEAD><STYLE TYPE="text/css"><!--
P { margin: 0 }
.KRCC { Name: Korean; lang: ko-KR; }
.ENCC { Name: English; lang: en-US; }
--></STYLE></HEAD><BODY>
<SYNC Start=1000><P Class=KRCC>안녕<br>하세요
<P Class=ENCC>Hello
<SYNC Start=3000><P Class=KRCC>&nbsp;
<SYNC Start=4000><P Class=ENCC>Only english
<SYNC Start="5000"><P class="krcc">잘 가요</P>
</BODY></SAMI>
''';

    test('只取首个 Class；&nbsp; 清屏决定前句终点；最后一句补默认时长', () {
      expect(
        _render(SamiParser.parseString(content: sami, bookKey: 'b')),
        <String>['1000-3000 안녕 하세요', '5000-10000 잘 가요'],
      );
    });

    test('无 <P> 的 SYNC 取整段', () {
      expect(
        _render(SamiParser.parseString(
          content: '<SYNC Start=0>A<SYNC Start=1000>B</BODY>',
          bookKey: 'b',
        )),
        <String>['0-1000 A', '1000-6000 B'],
      );
    });
  });

  group('TTML / DFXP', () {
    test('clock / tick / dur / br / span / 实体', () {
      const String ttml = '''<?xml version="1.0" encoding="UTF-8"?>
<tt xmlns="http://www.w3.org/ns/ttml"
    xmlns:ttp="http://www.w3.org/ns/ttml#parameter"
    ttp:tickRate="10000000" ttp:frameRate="25">
  <body><div>
    <p begin="00:00:01.000" end="00:00:02.500">吾輩は<br/>猫<span>である</span></p>
    <p begin="30000000t" dur="10000000t">Tom &amp; &lt;b&gt;</p>
    <p begin="5s" end="6500ms">B</p>
    <p begin="00:00:07:12" end="00:00:08:00">frames</p>
    <p begin="bad" end="00:00:09.000">skipped</p>
  </div></body>
</tt>''';
      expect(
        _render(TtmlParser.parseString(content: ttml, bookKey: 'b')),
        <String>[
          '1000-2500 吾輩は 猫である',
          '3000-4000 Tom & <b>',
          '5000-6500 B',
          '7480-8000 frames',
        ],
      );
    });

    test('非法 XML 抛异常（调用方归类为解析失败）', () {
      expect(
        () => TtmlParser.parseString(content: '<tt><p', bookKey: 'b'),
        throwsA(anything),
      );
    });
  });

  test('SBV', () {
    expect(
      _render(SbvParser.parseString(
        content: '0:00:01.000,0:00:02.000\nA\nB\n\n0:00:03.000,0:00:04.000\nC\n',
        bookKey: 'b',
      )),
      <String>['1000-2000 A B', '3000-4000 C'],
    );
  });

  group('扩展名唯一真相源', () {
    test('新扩展名路由到对应格式，大小写不敏感', () {
      expect(subtitleFormatForPath('/a/b.VTT'), SubtitleFormat.vtt);
      expect(subtitleFormatForPath('/a/b.smi'), SubtitleFormat.sami);
      expect(subtitleFormatForPath('/a/b.sami'), SubtitleFormat.sami);
      expect(subtitleFormatForPath('/a/b.ttml'), SubtitleFormat.ttml);
      expect(subtitleFormatForPath('/a/b.dfxp'), SubtitleFormat.ttml);
      expect(subtitleFormatForPath('/a/b.sbv'), SubtitleFormat.sbv);
      expect(subtitleFormatForPath('/a/b.ssa'), SubtitleFormat.ass);
      expect(subtitleFormatForPath('/a/b.sub'), isNull);
      expect(subtitleFormatForPath('/a/noext'), isNull);
    });

    test('白名单 = 路由表键集，每种格式都有解析器', () async {
      expect(kSubtitleFileExtensions, kSubtitleFormatByExtension.keys.toSet());
      for (final SubtitleFormat f in SubtitleFormat.values) {
        expect(
          kSubtitleFormatByExtension.containsValue(f),
          isTrue,
          reason: '$f 没有任何扩展名映射，外挂文件永远选不到它',
        );
        // 空内容不抛（TTML 除外：空串不是合法 XML）。
        if (f != SubtitleFormat.ttml) {
          expect(
            await parseSubtitleContentAsync(f, content: '', bookUid: 'b'),
            isEmpty,
          );
        }
      }
    });

    test('同目录 sidecar 扫描与互联上传白名单认新格式、仍拒绝穿越', () {
      expect(
        pickSameNameSubs(
          'ep01',
          <String>['ep01.ja.smi', 'ep01.ttml', 'ep01.txt', 'ep02.srt'],
          langCode: 'ja',
        ),
        <String>['ep01.ja.smi', 'ep01.ttml'],
      );
      expect(isSidecarSubtitleSuffix('.ko.smi'), isTrue);
      expect(isSidecarSubtitleSuffix('.dfxp'), isTrue);
      expect(isSidecarSubtitleSuffix('.SRT'), isTrue);
      expect(isSidecarSubtitleSuffix('.sub'), isFalse);
      expect(isSidecarSubtitleSuffix('/../x.srt'), isFalse);
      expect(isSidecarSubtitleSuffix('.a.b.srt'), isFalse);
      // 既有优先级不变：srt > ass > ssa > vtt，新格式排在后面。
      expect(
        pickSidecar('ep01', <String>['ep01.smi', 'ep01.vtt'], langCode: 'ja'),
        'ep01.vtt',
      );
    });
  });
}
