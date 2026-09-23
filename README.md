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
　24が設定されています。曲の速度を変更したいときに変化させてください。値が大きくなるとゆっくりに、小さくなると早くなります。

### 変換オプション
#### VelocityをGATE長へ反映
　MIDIのVelocity（通常は音の強さ）を、音を鳴らしている時間に変換する機能です。

　開発当初に音の厚みが欲しくて付けた機能ですが、あまり効果が感じられない気がします。

#### ハーモニーを補強する
　これも開発当初に音に厚みを付けるためにつけた機能ですが、今の変換方式では効果が無いと思います。

#### 主旋律優先(Melody Priority)
　同時に鳴る音が6物理CHを超える場合に、高い音を主旋律候補として優先的に残す機能です。

　CMU-800は6CHあるので最大6重和音出せますが、複数のパートや伴奏がある曲で6音以上の音がある場合に高い音の方が主旋律だろうと判断して残す機能です。

　ただし、最高音だから主旋律とは限りませんので万能ではありません。

#### Native Rhythm v4(オプション)
　以下のMIDIノート番号(GM音源)の場合リズムセクションと判断してCMU-800のリズム音に割り振る機能です。

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
