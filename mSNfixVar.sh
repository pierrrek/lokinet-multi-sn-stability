# cat /etc/ufw/applications.d/oxen-multi-sn

# check variables
instruction=NOTHING
instr="z$1"
if [ $instr == "zC" ] ; then
   echo "Create CODE to COPY files from BEST Node to other nodes and execute them"
   instruction=COPYONLY
elif [ $instr == "zS" ] ; then
   echo "Create STATEMENTS for an Update of the BEST Node"
   echo "Use these statements to run an update yourself."
   echo "Then use the C flag to update the other nodes"
   instruction=STATEMENTS
elif [ $instr == "zU" ] ; then
   echo "EXECUTES a FULL Update of the BEST Node"
   echo "Then use the C flag to update the other nodes"
   instruction=UPDATEONLY
elif [ $instr == "zF" ] ; then
   echo "EXECUTES a FULL Update of the BEST Node"
   echo "Then COPIES to all other nodes on the server"
   instruction=UPDATEANDCOPY
elif [ $instr == "zT" ] ; then
   echo "Execute code without heavy lifting"
   echo "This is used mainly for GIT Codespace testing."
   instruction=TESTING
else
   if [ $instr == "z" ] ; then
      echo " Error: No Flag Specified. See options below"
   else
      echo " Error: Incorrect Flag Specified! \"$1\" Is NOT an option"
   fi
   echo "Flags are:"
   echo "T - Execute without oxen related stuff"
   echo "S - Create STATEMENTS to Update Best node"
   echo "U - Execute UPDATES of Best Node"
   echo "C - COPY files from Best to other Nodes"
   echo "F - FULL: UPDATE Best node, COPY to others"
fi

# set up aliases for TESTING
if [ $instruction == "TESTING" ] || \
   [ $instruction == "NOTHING" ]
then
   echo "Setting up initial Test variables"
   alias oxend_all="cat oxend_all_example.txt"
   status=
   print_sn_status=
   urldir="https://raw.githubusercontent.com/pierrrek/lokinet-multi-sn-stability/main/lokirepo"
   log_file=log.mSNfixVar.log
   rm $log_file
else
   cmd_status=status
   cmd_print_sn_status=print_sn_status
   urldir="https://public.loki.foundation/loki"
   log_file=/var/log/mSNfixVar.`date +%Y%m%d%Hh%Mm%S`.log
fi
echo "Output will be written to $log_file"
touch $log_file

# get  list of all the nodes on this server
counter=0
NODES=
for NODE in `oxend_all $cmd_status | grep "oxend-"` ; do
  # nawk -F":" '{ print $1 }'
   NODEcurr=`echo $NODE | nawk -F: '{ print $1 }'`
   NODES[$counter]=$NODEcurr
   NODEID[$counter]=`echo $NODEcurr | nawk -F- '{ print $2 }'`
   NODENAME[$counter]=`echo "node-${NODEID[$counter]}"`
   #$NODE[1]
   # set up aliases for TESTING
   if [ $instruction == "TESTING" ] ; then
      #cat node_status_msg_example.txt | grep $NODEcurr | nawk -F~ '{ print $2 }' #| read variabllll
      alias $NODEcurr="cat node_status_msg_example.txt | grep $NODEcurr | nawk -F~ '{ print \$2 }'"
   fi
   counter=`expr $counter + 1`
done

if [ $instruction == "TESTING" ] ; then
   instruction="UPDATEANDCOPY"
fi

# get the blockcredit of each node
counter=0
BLOCKCREDIT=
for NODE in ${NODES[*]} ; do
   credit="$NODE $cmd_print_sn_status | grep 'Downtime Credits:' | nawk -F\" \" '{ print \$3 }'"
   echo $credit > runthisnow.sh
   chmod 700 runthisnow.sh
   . runthisnow.sh > blocks.data
   blocks=`cat blocks.data`
   if [ -z $blocks ] ; then
      blocks=0
   fi
   BLOCKCREDIT[$counter]=$blocks
   counter=`expr $counter + 1`
done
rm blocks.data

# get the block with the most credits
counter=0
BEST_NODE=$counter
BEST_NODE_credit=${BLOCKCREDIT[$BEST_NODE]}
for NODE in ${NODES[*]} ; do
   THIS_NODE_credit=${BLOCKCREDIT[$counter]}
   if [ $THIS_NODE_credit -gt $BEST_NODE_credit ] ; then
      BEST_NODE=$counter
      BEST_NODE_credit=$THIS_NODE_credit
   fi
   counter=`expr $counter + 1`
done

message="Best Node: ${NODEID[$BEST_NODE]} ${NODENAME[$BEST_NODE]} ${NODES[$BEST_NODE]} ${BLOCKCREDIT[$BEST_NODE]} Downtime Blocks"
echo $message && echo $message >>$log_file

#get second best node
counter=0
SECOND_NODE=$counter
SECOND_NODE_credit=$counter #${BLOCKCREDIT[$BEST_NODE]}
for NODE in ${NODES[*]} ; do
   THIS_NODE_credit=${BLOCKCREDIT[$counter]}
   if [ $THIS_NODE_credit -gt $SECOND_NODE_credit ] && [ $THIS_NODE_credit -lt $BEST_NODE_credit ] ; then
      SECOND_NODE=$counter;
      SECOND_NODE_credit=$THIS_NODE_credit
   fi
   counter=`expr $counter + 1`
done

message="2nd Node : ${NODEID[$SECOND_NODE]} ${NODENAME[$SECOND_NODE]} ${NODES[$SECOND_NODE]} ${BLOCKCREDIT[$SECOND_NODE]}"
echo $message && echo $message >>$log_file

# do some cleanup
df -k . && sleep 1 && sudo journalctl --vacuum-time=2h && sleep 1 && df -k . | grep "Vacuuming done" >>$log_file

# if instructed to do so, delete the files of the node
# with the most uptime block reserve, restart it a
# number of times so that it can sync
# it will return downtime errors so monitor it
if [ $instruction == "UPDATEANDCOPY" ] || \
   [ $instruction == "UPDATEONLY" ] || \
   [ $instruction == "STATEMENTS" ]
then
   echo "#####################################################"
   echo "Create CODE to UPDATE all Database files of BEST Node"
   echo "sudo systemctl stop lokinet-router@${NODEID[$BEST_NODE]} oxen-storage-server@${NODEID[$BEST_NODE]} oxen-node@${NODEID[$BEST_NODE]}" > runthisnow.sh
   echo "cd /var/lib/oxen/${NODENAME[$BEST_NODE]}/" >> runthisnow.sh
#   echo "rm sqlite.db ons.db lmdb/data.mdb" >> runthisnow.sh
#   echo "#### You can try these also to put back the files ####"  >> runthisnow.sh
   echo "sudo curl ${urldir}/sqlite.db >sqlite.db"  >> runthisnow.sh
   echo "sudo curl ${urldir}/ons.db >ons.db" >> runthisnow.sh
#   echo "sudo systemctl start lokinet-router@${NODEID[$BEST_NODE]} oxen-storage-server@${NODEID[$BEST_NODE]} oxen-node@${NODEID[$BEST_NODE]}" >> runthisnow.sh
#   echo "sudo systemctl restart lokinet-router@${NODEID[$BEST_NODE]} oxen-storage-server@${NODEID[$BEST_NODE]} oxen-node@${NODEID[$BEST_NODE]}" >> runthisnow.sh
#   echo "##### WAIT TILL THE SYSTEM IS RECOMMISSIONED BEFORE CONTINUING #####" >> runthisnow.sh
#   echo "sudo systemctl stop lokinet-router@${NODEID[$BEST_NODE]} oxen-storage-server@${NODEID[$BEST_NODE]} oxen-node@${NODEID[$BEST_NODE]}" >> runthisnow.sh
   echo "sudo curl ${urldir}/data.mdb >lmdb/data.mdb" >> runthisnow.sh
   echo "sudo systemctl start lokinet-router@${NODEID[$BEST_NODE]} oxen-storage-server@${NODEID[$BEST_NODE]} oxen-node@${NODEID[$BEST_NODE]}" >> runthisnow.sh
   echo "sudo systemctl restart lokinet-router@${NODEID[$BEST_NODE]} oxen-storage-server@${NODEID[$BEST_NODE]} oxen-node@${NODEID[$BEST_NODE]}" >> runthisnow.sh
   echo "ll ../node-0*/lmdb/data.mdb && ll ../node-0*/*.db && oxend_all status" >> runthisnow.sh
   echo "COMMANDS TO BE EXECUTED for UPDATE"
   echo "----------------------------------"
   cat runthisnow.sh
   if [ $instruction == "STATEMENTS" ]  ; then
      echo "##############################################"
      echo "##     NOT executing now...                 ##"
      echo "##############################################"
      echo "###### Execute these commands yourself! ######"
   fi
fi

if [ $instruction == "UPDATEANDCOPY" ] || \
   [ $instruction == "UPDATEONLY" ] || \ 
   [ $instruction == "TESTING" ]
then
   echo "#####################################################"
   echo "### EXECUTING UPDATE... `date`"
   echo "#####################################################"
   echo "### Files Copied! `date`"
   . runthisnow.sh >>$log_file
fi

# copy the best files to the second best node
if [ $instruction == "UPDATEANDCOPY" ] || \
   [ $instruction == "COPYONLY" ] || \
   [ $instruction == "STATEMENTS" ]
then
   echo "#######################################################"
   echo "Create CODE to COPY files from Best to SECOND Best Node"
   echo "sudo systemctl stop lokinet-router@${NODEID[$SECOND_NODE]} oxen-storage-server@${NODEID[$SECOND_NODE]} oxen-node@${NODEID[$SECOND_NODE]}" > runthisnow.sh
   echo "sudo systemctl stop lokinet-router@${NODEID[$BEST_NODE]} oxen-storage-server@${NODEID[$BEST_NODE]} oxen-node@${NODEID[$BEST_NODE]}" >> runthisnow.sh
   echo "cp /var/lib/oxen/${NODENAME[$BEST_NODE]}/sqlite.db /var/lib/oxen/${NODENAME[$SECOND_NODE]}/sqlite.db" >> runthisnow.sh
   echo "cp /var/lib/oxen/${NODENAME[$BEST_NODE]}/ons.db /var/lib/oxen/${NODENAME[$SECOND_NODE]}/ons.db" >> runthisnow.sh
   echo "cp /var/lib/oxen/${NODENAME[$BEST_NODE]}/lmdb/data.mdb /var/lib/oxen/${NODENAME[$SECOND_NODE]}/lmdb/data.mdb" >> runthisnow.sh
   echo "sudo systemctl start lokinet-router@${NODEID[$BEST_NODE]} oxen-storage-server@${NODEID[$BEST_NODE]} oxen-node@${NODEID[$BEST_NODE]}" >> runthisnow.sh
   echo "sudo systemctl start lokinet-router@${NODEID[$SECOND_NODE]} oxen-storage-server@${NODEID[$SECOND_NODE]} oxen-node@${NODEID[$SECOND_NODE]}" >> runthisnow.sh
   echo "sudo systemctl restart lokinet-router@${NODEID[$SECOND_NODE]} oxen-storage-server@${NODEID[$SECOND_NODE]} oxen-node@${NODEID[$SECOND_NODE]}" >> runthisnow.sh
   echo "COMMANDS TO BE EXECUTED for Copy 1"
   echo "----------------------------------"
   cat runthisnow.sh
fi

if [ $instruction == "UPDATEANDCOPY" ] || \
   [ $instruction == "COPYONLY" ]
then
   echo "#####################################################"
   echo "### EXECUTING COPY 1 ... `date`"
   echo "#####################################################"
   . runthisnow.sh >>$log_file
   echo "#####################################################"
   echo "### Files Copied! `date`"
fi

# copy the second best files to the rest of the nodes
if [ $instruction == "UPDATEANDCOPY" ] || \
   [ $instruction == "COPYONLY" ] || \
   [ $instruction == "STATEMENTS" ]
then
   echo "#################################################"
   echo "Create CODE to COPY files from 2nd to OTHER Nodes"
   echo "sudo systemctl stop lokinet-router@${NODEID[$SECOND_NODE]} oxen-storage-server@${NODEID[$SECOND_NODE]} oxen-node@${NODEID[$SECOND_NODE]}" > runthisnow.sh
   counter=0
   for NODE in ${NODES[*]} ; do
      if [ $counter == $SECOND_NODE ] ; then
         echo "do nothing for node $NODE"
      elif [ $counter == $BEST_NODE ] ; then
         echo "do nothing for node $NODE"
      else
         echo "sudo systemctl stop lokinet-router@${NODEID[$counter]} oxen-storage-server@${NODEID[$counter]} oxen-node@${NODEID[$counter]}" >> runthisnow.sh
         echo "cp /var/lib/oxen/${NODENAME[$SECOND_NODE]}/sqlite.db /var/lib/oxen/${NODENAME[$counter]}/sqlite.db" >> runthisnow.sh
         echo "cp /var/lib/oxen/${NODENAME[$SECOND_NODE]}/ons.db /var/lib/oxen/${NODENAME[$counter]}/ons.db" >> runthisnow.sh
         echo "cp /var/lib/oxen/${NODENAME[$SECOND_NODE]}/lmdb/data.mdb /var/lib/oxen/${NODENAME[$counter]}/lmdb/data.mdb" >> runthisnow.sh
         echo "sudo systemctl start lokinet-router@${NODEID[$counter]} oxen-storage-server@${NODEID[$counter]} oxen-node@${NODEID[$counter]}" >> runthisnow.sh
         echo "sudo systemctl restart lokinet-router@${NODEID[$counter]} oxen-storage-server@${NODEID[$counter]} oxen-node@${NODEID[$counter]}" >> runthisnow.sh
      fi
      counter=`expr $counter + 1`
   done
   echo "sudo systemctl start lokinet-router@${NODEID[$SECOND_NODE]} oxen-storage-server@${NODEID[$SECOND_NODE]} oxen-node@${NODEID[$SECOND_NODE]}" >> runthisnow.sh
   echo "COMMANDS TO BE EXECUTED for Copy 2"
   echo "----------------------------------"
   cat runthisnow.sh
fi

if [ $instruction == "UPDATEANDCOPY" ] || \
   [ $instruction == "COPYONLY" ]
then
   echo "#####################################################"
   echo "### EXECUTING COPY 2 ... `date`"
   echo "#####################################################"
   . runthisnow.sh >>$log_file
   echo "#####################################################"
   echo "### Files Copied! `date`"
   echo "#####################################################"
fi

