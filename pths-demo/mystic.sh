while true ; do
    echo "what to do? (encrypt, decrypt):"
    read op
    if [ $op == "encrypt" ] ; then
        src='_demo-set.txt'
        dst='demo-set.enc'
        break
    fi
    if [ $op == "decrypt" ] ; then
        src='demo-set.enc'
        dst='_demo-set.txt'
        if [ -f $dst ] ; then
            cp $dst _demo-set.bak
        fi
        break
    fi
    echo "let's retry..."
done

echo "Encryption key, please:"
read pwd

echo "$src -> $dst"
echo "proceed?"
read sure
if [ $sure != "y" ] ; then
    echo "interrupted, exiting"
    exit
fi
perl ../utils/crypter.pl $pwd <$src >$dst
echo "done!"
