#第三回 課題3-2: マルチプルテーブルを読む

##提出者
氏名：木藤嵩人

##課題内容
OpenFlow1.3 版スイッチの動作を説明しよう。

スイッチ動作の各ステップについて、trema dump_flows の出力 (マルチプルテーブルの内容) を混じえながら動作を説明すること。


##解答
ネットワークの設定は以下のように行った。
```
vswitch('lsw') {
  datapath_id 0xabc
}

vhost ('host1') {
  ip '192.168.0.1'
  mac "00:00:00:00:00:01"
}

vhost ('host2') {
  ip '192.168.0.2'
  mac "00:00:00:00:00:02"
}

link 'lsw', 'host1'
link 'lsw', 'host2'
```
初期状態のフローテーブルを確認すると以下のようになっていた。
```
cookie=0x0, duration=33.951s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop
cookie=0x0, duration=33.913s, table=0, n_packets=16, n_bytes=3187, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop
cookie=0x0, duration=33.913s, table=0, n_packets=7, n_bytes=2394, priority=1 actions=goto_table:1
cookie=0x0, duration=33.913s, table=1, n_packets=7, n_bytes=2394, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD
cookie=0x0, duration=33.913s, table=1, n_packets=0, n_bytes=0, priority=1 actions=CONTROLLER:65535
```
priority=3:宛先MACアドレスがff:ff:ff:ff:ff:ffであった場合，フラッディングする．これはブロードキャストパケットを表している。
priority=2:宛先MACアドレスが01:00:00:00:00:00/ff:00:00:00:00:00であればdropする。これはipv6のマルチキャストを表している。
           宛先MACアドレスが33:33:00:00:00:00/ff:ff:00:00:00:00であればdropする．これはipv6のマルチキャストを表している。
priority=1:table1（転送テーブル）に遷移する。
		コントローラにPacket_in()する。
到着したパケットはtable0のpriorityの高いものから処理される。このため、table0ははじめにマルチキャストのパケットを落とすフィルタとして機能していることがわかる。

次に`host1`から`host2`へのパケットの送信を行った。
```
cookie=0x0, duration=1202.499s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop
cookie=0x0, duration=1202.461s, table=0, n_packets=532, n_bytes=98812, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop
cookie=0x0, duration=1202.461s, table=0, n_packets=138, n_bytes=46896, priority=1 actions=goto_table:1
cookie=0x0, duration=1202.461s, table=1, n_packets=137, n_bytes=46854, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD
cookie=0x0, duration=1202.461s, table=1, n_packets=1, n_bytes=42, priority=1 actions=CONTROLLER:65535
```
コントローラへパケットインが発生したと考えられるが、まだフローテーブルには反映されない。さらに`host2`から`host1`へのパケットの送信を行った。
```
cookie=0x0, duration=1213.833s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop
cookie=0x0, duration=1213.795s, table=0, n_packets=532, n_bytes=98812, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop
cookie=0x0, duration=1213.795s, table=0, n_packets=139, n_bytes=46938, priority=1 actions=goto_table:1
cookie=0x0, duration=1213.795s, table=1, n_packets=137, n_bytes=46854, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD
cookie=0x0, duration=2.174s, table=1, n_packets=0, n_bytes=0, idle_timeout=180, priority=2,in_port=2,dl_src=00:00:00:00:00:02,dl_dst=00:00:00:00:00:01 actions=output:1
cookie=0x0, duration=1213.795s, table=1, n_packets=2, n_bytes=84, priority=1 actions=CONTROLLER:65535
```
これにより、table1に`host2`から`host1`へのエントリが追加されたことがわかる。

最後に`host1`から`host2`へのパケットの送信を行った。
```
cookie=0x0, duration=1492.694s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop
cookie=0x0, duration=1492.656s, table=0, n_packets=580, n_bytes=107593, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop
cookie=0x0, duration=1492.656s, table=0, n_packets=148, n_bytes=49716, priority=1 actions=goto_table:1
cookie=0x0, duration=1492.656s, table=1, n_packets=145, n_bytes=49590, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD
cookie=0x0, duration=2.454s, table=1, n_packets=0, n_bytes=0, idle_timeout=180, priority=2,in_port=1,dl_src=00:00:00:00:00:01,dl_dst=00:00:00:00:00:02 actions=output:2
cookie=0x0, duration=1492.656s, table=1, n_packets=3, n_bytes=126, priority=1 actions=CONTROLLER:65535
```
すると、`host1`から`host2`へのエントリのみが存在し、`host2`から`host1`へのエントリは存在しなかった。
これは、idle_timeout=180となっているところから考えると、操作の間隔が開いたため、タイムアウトでエントリが削除されたものと考えられる。
そこで、素早く`host1`から`host2`へのパケットの送信と`host2`から`host1`へのパケットの送信を行いフローエントリを確認したところ以下のようになった。
```
cookie=0x0, duration=1906.847s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop
cookie=0x0, duration=1906.809s, table=0, n_packets=724, n_bytes=134237, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop
cookie=0x0, duration=1906.809s, table=0, n_packets=188, n_bytes=62496, priority=1 actions=goto_table:1
cookie=0x0, duration=1906.809s, table=1, n_packets=182, n_bytes=62244, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD
cookie=0x0, duration=1.483s, table=1, n_packets=0, n_bytes=0, idle_timeout=180, priority=2,in_port=1,dl_src=00:00:00:00:00:01,dl_dst=00:00:00:00:00:02 actions=output:2
cookie=0x0, duration=22.942s, table=1, n_packets=0, n_bytes=0, idle_timeout=180, priority=2,in_port=2,dl_src=00:00:00:00:00:02,dl_dst=00:00:00:00:00:01 actions=output:1
cookie=0x0, duration=1906.809s, table=1, n_packets=6, n_bytes=252, priority=1 actions=CONTROLLER:65535
```
期待したように、table1に`host1`と`host2`間の双方向のエントリがあることが確認できた。
