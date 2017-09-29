#!/bin/bash
#允许的进程数
THREAD_NUM=200
#定义描述符为9的管道
tmp_fifofile="/tmp/$$.fifo"
mkfifo "$tmp_fifofile"
exec 9<>"$tmp_fifofile"

#预先写入指定数量的换行符，一个换行符代表一个进程
for ((i=0;i<$THREAD_NUM;i++))
do
    echo -ne "\n" 1>&9
done

if [ $# != 1 ] ;then
        echo "The parameters you enter is not correct !";
        exit -1;
fi

while read line
do
{
    #进程控制
    read -u 9
    {
        #isok=`curl -I -o /dev/null -s -w %{http_code} $line`
        if [ "$isok" = "200" ]; then
            echo $line "OK"
        else
            echo $line "no"
        fi
        echo -ne "\n" 1>&9
    }&
}
done < $1
wait
echo "执行结束"
rm "$tmp_fifofile"


