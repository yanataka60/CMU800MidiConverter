# CMU800MidiConverter

　MIDIデータをえむこまさんのMZ-2000用CMU-800プレーヤー CMU-800PLAYERで使えるデータに変換するツールです。

https://github.com/mkomakonkon/MZ-2000/tree/master/misc/CMU-800/PLAYER

　CMU-800を持っていなくともkuran_kuranさんの「Common Source Code Project EmuZ-2200/EmuZ-80B mz2000_sd/CMU-800 MIDI対応版」で利用できます。

https://daimonsoft.info/argo/download.html

## 使い方
　Windows 7 SP1 〜 Windows 11で実行できます。好きなフォルダに「CMU800MidiConverter.exe」を置いて使ってください。

　簡単に使うにはMIDI DATA(入力)にMIDIファイルをドロップして変換開始ボタンを押し、出来上がったmztファイルをCMU-800PLAYERに読み込ませるだけです。

![Converter](https://github.com/yanataka60/CMU800MidiConverter/blob/main/photo/start.png)


### MIDI DATA(入力)
　変換したいMIDIデータをドロップするか、Browseから選択します。

　拡張子は、MIDまたはMIDIがデフォルトです。

　ここで選択されたMIDIファイルのあるフォルダはCMU800MidiConverterを終了するときに記憶され、次に使うときには記憶されたフォルダからファイルを選択できます。

### CMU DATA(出力)
　MIDI DATA(入力)に入力されたファイル名の拡張子をmztに変えたファイル名が設定されます。

　変更したければ入力するか、Browseから選択します。

　拡張子をmzt以外に設定するとmztヘッダのつかないCMUデータそのもののバイナリファイルになります。

### Load address(hex)
　CMU-800PLAYERで使う「337D」が設定されています。

### Steps / quarter note
　44が初期値として設定されています。曲の速度を変更したいときに変化させてください。値が大きくなるとゆっくりに、小さくなると早くなります。

　CMU800MidiConverterを終了するときに値が記憶されます。44に戻したいときには「初期値に戻す」ボタンを押してください。

### 変換オプション
#### VelocityをGATE長へ反映
　MIDIのVelocity（通常は音の強さ）を、音を鳴らしている時間に変換する機能です。

　開発当初に音の厚みが欲しくて付けた機能ですが、あまり効果が感じられない気がします。

#### 主旋律優先(Melody Priority)
　同時に鳴る音が6物理CHを超える場合に、高い音を主旋律候補として優先的に残す機能です。

　CMU-800は6物理CHあるので最大6重和音出せますが、複数のパートや伴奏がある曲で6音以上の音を同時に鳴らす必要がある場合に高い音の方が主旋律だろうと判断します。

　ただし、最高音だから主旋律とは限りませんので万能ではありません。

#### Native Rhythm v4(オプション)
　以下のMIDIノート番号(GM音源)の場合リズムセクションと判断してCMU-800の内蔵リズム音に割り振る機能です。

　リズムセクションを含まない曲では効果はありません。

|内蔵リズム音|MIDIノート番号（GM音源）|
| ---------- | ------------ |
|BD|35(ABD),36(BD)|
|SD|38(SD),40(ESD)|
|LT|41(FT),43(HFT),45(LT),47(LMT)|
|MT|48(HMT),50(HT)|
|CY|49(CR1),57(CR2),51,52,53,55,59|
|OH|46(OH)|
|CH|42(CH)|

## 謝辞
　MIDIデータおよびCMUデータの解析に以下の資料、プログラムを使わせていただきました。ありがとうございました。

・kuran_kuran様のサイト「アルゴの記憶」

https://daimonsoft.info/argo/main.html#argo

・えむこま様のCMU-800PLAYER、mid2cmu、cmuadd

https://github.com/mkomakonkon/MZ-2000/tree/master/misc/CMU-800
