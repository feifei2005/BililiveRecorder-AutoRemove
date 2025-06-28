# BililiveRecorder-AutoRemove
自动删除“https://github.com/BililiveRecorder/BililiveRecorder”早期的录播以实现循环录制

实际就是个Python脚本，检测文件夹有多大，大于阈值就删除修改日期最早的文件，针对BililiveRecorder的保存形式做了适配。
我在python3.11上运行正常，deepseek说它能兼容python3.6以上的python环境，但是没有测试过。
