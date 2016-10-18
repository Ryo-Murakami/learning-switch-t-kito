#第二回 課題2-2: 複数スイッチ対応版 ラーニングスイッチ

##提出者
氏名：木藤嵩人

##課題内容
複数スイッチに対応したラーニングスイッチ (multi_learning_switch.rb) の動作を説明しよう。

##解答
###ソースコード
```
  def start(_argv)
    @fdbs = {}
    logger.info "#{name} started."
  end
```
@fdb = FDB.newという形で定義するのではなく、@fdbs = {}というようにFDBの連想配列として記述することで、複数のスイッチに対応している。


```
  def switch_ready(datapath_id)
    @fdbs[datapath_id] = FDB.new
  end
```
switch_ready()はスイッチが接続された時に呼び出されるため、ここでdatapath_idを用いて新しいFDBを作成することで、スイッチごとのFDBを作成することができる。

```
  def packet_in(datapath_id, packet_in)
    return if packet_in.destination_mac.reserved?
    @fdbs.fetch(datapath_id).learn(packet_in.source_mac, packet_in.in_port)
    flow_mod_and_packet_out packet_in
  end
```
packet_inが発生した場合、パケットが入ってきたポートとmacアドレスを記憶して置く必要があるため、datapath_idのFDBに記録している。

```
  def age_fdbs
    @fdbs.each_value(&:age)
  end
```
各FDBのエージングを行う。

```
  def flow_mod_and_packet_out(packet_in)
    port_no = @fdbs.fetch(packet_in.dpid).lookup(packet_in.destination_mac)
    flow_mod(packet_in, port_no) if port_no
    packet_out(packet_in, port_no || :flood)
  end
```
packet_inのあったスイッチのFDBを参照し、宛先となるMACアドレスが存在するかを確認する。
FDBに宛先アドレスが存在する場合、flow_modメッセージを作成し、フローテーブルを更新し、宛先アドレスのポートへpacket_outする。
宛先アドレスが存在しない場合はフラッディングを行う。

```
  def flow_mod(packet_in, port_no)
    send_flow_mod_add(
      packet_in.datapath_id,
      match: ExactMatch.new(packet_in),
      actions: SendOutPort.new(port_no)
    )
  end
```
flow_modメッセージを作成する。

```
  def packet_out(packet_in, port_no)
    send_packet_out(
      packet_in.datapath_id,
      packet_in: packet_in,
      actions: SendOutPort.new(port_no)
    )
  end
```
packet_outを行う。

###動作確認
配布されていたtrema.multi.confを以下のように一部変更し、各ホストにIPアドレスとMACアドレスを設定した。
```
vswitch('lsw1') { datapath_id 0x1 }
vswitch('lsw2') { datapath_id 0x2 }
vswitch('lsw3') { datapath_id 0x3 }
vswitch('lsw4') { datapath_id 0x4 }

vhost('host1-1'){
ip "192.168.0.11"
mac "00:00:00:00:00:11"
}
vhost('host1-2'){
ip "192.168.0.12"
mac "00:00:00:00:00:12"
}
vhost('host2-1'){
ip "192.168.0.21"
mac "00:00:00:00:00:21"
}
vhost('host2-2'){
ip "192.168.0.22"
mac "00:00:00:00:00:22"
}
vhost('host3-1'){
ip "192.168.0.31"
mac "00:00:00:00:00:31"
}
vhost('host3-2'){
ip "192.168.0.32"
mac "00:00:00:00:00:32"
}
vhost('host4-1'){
ip "192.168.0.41"
mac "00:00:00:00:00:41"
}
vhost('host4-2'){
ip "192.168.0.42"
mac "00:00:00:00:00:42"
}

link 'lsw1', 'host1-1'
link 'lsw1', 'host1-2'
link 'lsw2', 'host2-1'
link 'lsw2', 'host2-2'
link 'lsw3', 'host3-1'
link 'lsw3', 'host3-2'
link 'lsw4', 'host4-1'
link 'lsw4', 'host4-2'
```
これによって、今回の環境は以下のように構成されている。

```
コントローラ
｜    ｜＼＿lsw1ーーhost1-1 (IP:192.168.0.11, MAC:00:00:00:00:00:11)
｜    ｜        ＼＿host1-2 (IP:192.168.0.12, MAC:00:00:00:00:00:12)
｜    ｜＼＿lsw2ーーhost2-1 (IP:192.168.0.21, MAC:00:00:00:00:00:21)
｜    ｜        ＼＿host2-2 (IP:192.168.0.22, MAC:00:00:00:00:00:22)
｜    ｜＼＿lsw3ーーhost3-1 (IP:192.168.0.31, MAC:00:00:00:00:00:31)
｜    ｜        ＼＿host3-2 (IP:192.168.0.32, MAC:00:00:00:00:00:32)
｜ 　   ＼＿lsw4ーーhost4-1 (IP:192.168.0.41, MAC:00:00:00:00:00:41)
｜             ＼＿host4-2 (IP:192.168.0.42, MAC:00:00:00:00:00:42)
```

まず、双方向でパケットを送信することでフローエントリが更新されることを確かめた。
1. host1-1からhost1-2へパケットを送信する。
結果
```
$ ./bin/trema send_packets --source host1-1 --dest host1-2
$ ./bin/trema dump_flows lsw1

$
$ ./bin/trema show_stats host1-1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 1 packet
```
結果より、host1-1からhost1-2へパケットを送信されているが、lsw1のフローテーブルには変化がないことがわかる。

2. host1-2からhost1-1へパケットを送信する。
結果
```
$ ./bin/trema send_packets --source host1-2 --dest host1-1
$ ./bin/trema show_stats host1-1
Packets sent:
  192.168.0.11 -> 192.168.0.12 = 1 packet
Packets received:
  192.168.0.12 -> 192.168.0.11 = 1 packet
$ ./bin/trema show_stats host1-2
Packets sent:
  192.168.0.12 -> 192.168.0.11 = 1 packet
Packets received:
  192.168.0.11 -> 192.168.0.12 = 1 packet
$ ./bin/trema dump_flows lsw1cookie=0x0, duration=9.184s, table=0, n_packets=0, n_bytes=0, idle_age=9, priority=65535,udp,in_port=2,vlan_tci=0x0000,dl_src=00:00:00:00:00:12,dl_dst=00:00:00:00:00:11,nw_src=192.168.0.12,nw_dst=192.168.0.11,nw_tos=0,tp_src=0,tp_dst=0 actions=output:1
```
結果より、host1-2からhost1-1へパケットを送信され、lsw1のフローテーブルに新たに"ポート2に入ってきたdl_src=00:00:00:00:00:12,dl_dst=00:00:00:00:00:11のパケットをポート１に出力する"というルールが追加されていることがわかる。

3. もういちどhost1-1からhost1-2へパケットを送信する。
結果
```
$ ./bin/trema send_packets --source host1-1 --dest host1-2
$ ./bin/trema show_stats host1-1
Packets sent:
  192.168.0.11 -> 192.168.0.12 = 2 packets
Packets received:
  192.168.0.12 -> 192.168.0.11 = 1 packet
$ ./bin/trema dump_flows lsw1cookie=0x0, duration=9.166s, table=0, n_packets=0, n_bytes=0, idle_age=9, priority=65535,udp,in_port=1,vlan_tci=0x0000,dl_src=00:00:00:00:00:11,dl_dst=00:00:00:00:00:12,nw_src=192.168.0.11,nw_dst=192.168.0.12,nw_tos=0,tp_src=0,tp_dst=0 actions=output:2
cookie=0x0, duration=131.132s, table=0, n_packets=0, n_bytes=0, idle_age=131, priority=65535,udp,in_port=2,vlan_tci=0x0000,dl_src=00:00:00:00:00:12,dl_dst=00:00:00:00:00:11,nw_src=192.168.0.12,nw_dst=192.168.0.11,nw_tos=0,tp_src=0,tp_dst=0 actions=output:1
```
結果より、host1-1からhost1-2へパケットを送信され、lsw1のフローテーブルに"ポート1に入ってきたdl_src=00:00:00:00:00:11,dl_dst=00:00:00:00:00:12のパケットをポート2に出力する"というルールが追加されていることがわかる。

以上の結果より、双方向でパケットを送信することでフローエントリが更新されることが確かめられた。
lsw2, lsw3, lsw4においても、全く同じ手順で設定可能なので、反復構築などが容易である。

最後に、host1-1からhost2-1へのパケット送信のテストをした。
あらかじめ、先の手順でlsw2の設定を行った上で、host1-1からhost2-1へのパケット送信を行った。
```
結果
$ ./bin/trema send_packets --source host1-1 --dest host2-1
$ ./bin/trema show_stats host1-1
Packets sent:
  192.168.0.11 -> 192.168.0.12 = 2 packets
  192.168.0.11 -> 192.168.0.21 = 1 packet
Packets received:
  192.168.0.12 -> 192.168.0.11 = 1 packet
$ ./bin/trema show_stats host2-1
Packets sent:
  192.168.0.21 -> 192.168.0.22 = 2 packets
Packets received:
  192.168.0.22 -> 192.168.0.21 = 1 packet
```
結果より、host1-1からパケットを送信したが、host2-1には到達しなかったことがわかる。
この動作は、まずhost1-1がlse1へパケットを送信する。次にlsw1がフローテーブルを参照し、該当する条件がないためコントローラーに問い合わせを行う。コントローラーはパケットの情報を記録し、フラッディングを行うが、lsw1とlsw2は論理的に接続されていないためパケットは喪失される。
