#!/bin/sh
mn -c 

cdate=$(date +"%Y%m%d")

DURATION=120
iperf="iperf"
mdtcp_debug=0
queue_size=200

# test=0 throughput test, test=1 FCT
qmon=0
bwm=0
tcpdump=0
tcpprobe=0

num_reqs=2000

cdir=$(pwd)
echo $cdir
export PYTHONPATH=${PYTHONPATH}:$cdir/src
mkdir -p plots

# killall python
 
ctrl=$( ps ax | grep DCController | wc -l )

controllerId=0
hosts_per_edge=5

if [ $ctrl -le 1 ] ;
then 
  python src/pox/pox.py DCController --topo=ft,4,$hosts_per_edge --routing=ECMP &
  controllerId=$!
  echo $controllerId
fi

sleep 1

# proto 0=mptcp, proto=1=mdtcp

m=1
bw=100
bwh=100

delay=0.1

seed=754

while [ $m -le 1 ] ; 
do
  seed=$(( seed + m )) 

  for mytest in 0 ;
  do 
    for WORKLOAD in 'one_to_one';
    do 
    # 0.2 0.4 0.6 0.8 0.9 ;
    for load in 1.0  ; 
    do 
      
      dload=$(echo "scale=4; $bw*$load" | bc)
     
      #generate traffic for the desired load

      if [ $mytest -eq 1 ]; 
      then 
        echo $dload
        cd ../Trace-generator
        rm  trace_file/mdtcp-output.trace
        ./trace_generator $dload $num_reqs $seed $hosts_per_edge
        cd ../ecmp-controller
      fi

     
     # cp ../Trace-generator/trace_file/mdtcp-output.trace requests_load$dload

      for pod in 4 ; 
      do 
        for proto in 1 0   ;
        do 
          for subflows in 1 2 3 4 8; 
          do
            # find . -name 'ss_clnt_10*' | xargs rm -f
            
            if [ $tcpprobe -eq 1 ] ;
            then 
              modprobe tcp_probe
            fi

            #echo > /dev/null | sudo tee /var/log/syslog
            #echo > /dev/null | sudo tee /var/log/kern.log
            
           
            echo "Iteration "$m" load: "$load
            rm ss_clnt* ss_serv* flows_10* log_10*
            # cdate=$(date +"%Y%m%d")
            if [ $proto -eq 1 ] ;
            then 
              redmax=31000
              redmin=30000
              redburst=30
            	redprob=1.0
            	enable_ecn=1
            	enable_red=0
            	mdtcp=1
            	dctcp=0

              if [ $mytest -eq 1 ] ;
              then
               
                subdir='fct-mdtcp-'$cdate'-bw-tcpdump'$bw'delay'$delay'ft'$pod'hostsPerEdge'$hosts_per_edge'load'$load'num_reqs'$num_reqs
              elif [ $mytest -eq 0 ]; 
                then
                  
                  subdir='goodput-mdtcp-'$cdate'-bw'$bw'delay'$delay'ft'$pod'hostsPerEdge'$hosts_per_edge
                fi
              elif [ $proto -eq 0 ]; 
                then
                  enable_ecn=0
                  enable_red=1
                  redmax=120000
                  redmin=30000
                  redburst=50
                  redprob=0.01
                	mdtcp=0
                	dctcp=0
                  if [ $mytest -eq 1 ] ;
                  then
                    
                    subdir='fct-mptcp-'$cdate'-bw-nonetem'$bw'delay'$delay'ft'$pod'hostsPerEdge'$hosts_per_edge'load'$load'num_reqs'$num_reqs
                  elif [ $mytest -eq 0 ]; 
                    then
                     
                      subdir='goodput-mptcp-'$cdate'-bw'$bw'delay'$delay'ft'$pod'hostsPerEdge'$hosts_per_edge
                    fi
                  fi
                  
                  out_dir=results/$subdir/$WORKLOAD

                  ping=$cdate'-bw'$bw'delay'$delay'ft'$pod'hostsPerEdge'$hosts_per_edge'/'$WORKLOAD'/flows'

                  
                  python src/fattree.py -d $out_dir -t $DURATION --ecmp --iperf \
                  --workload $WORKLOAD --K $pod --bw $bw --bwh $bwh --delay $delay --mdtcp $mdtcp --dctcp $dctcp --redmax $redmax\
                  --redmin $redmin --burst  $redburst --queue  $queue_size --prob $redprob --enable_ecn $enable_ecn\
                  --enable_red $enable_red --subflows $subflows --mdtcp_debug $mdtcp_debug --num_reqs $num_reqs\
                  --test $mytest --qmon $qmon --iter $m   --load $load --bwm  $bwm --tcpdump $tcpdump --tcpprobe $tcpprobe --hedge $hosts_per_edge

                  if [ $mytest -eq 1 ];
                  then 
                    cp ../Trace-generator/trace_file/mdtcp-output.trace $out_dir
                    mv $out_dir/mdtcp-output.trace $out_dir/requests_load$dload
                  fi


                  sudo mn -c

                # Plots 

                   if [ $mytest -eq 1 ]
                   then 
                     python src/process/process_fct.py  -s $subflows -f results/$subdir/$WORKLOAD/*/flows_10* -o plots/$subdir-$WORKLOAD.png
                   fi

                  if [ $qmon -eq 1 ]
                  then
                    for f in $subflows
                    do
                      python src/process/plot_queue_cdf.py -f results/$subdir/$WORKLOAD/flows$f/queue_size* -b $bw -m $queue_size -o plots/$subdir-$WORKLOAD-flows$f
                      #python src/process/plot_ping.py -f results/$subdir/$WORKLOAD/flows$f/ping* -b $bw  -o plots/$subdir-$WORKLOAD-flows$f

                    done
                  fi

              	  if [ $bwm -eq 1 ]
              	  then
              	  for f in $subflows
              	  do
                    python src/process/process_bwm_ng_rates.py -f results/$subdir/$WORKLOAD/flows$f/rates_iter* -b $bw -o plots/$subdir-$WORKLOAD-flows$f
              	  done 
              	  fi

                sleep 1

                done #subflow

                if [ $mytest -eq 0 ]
                then 
                  python src/process/plot_hist_all.py -k $pod -bw $bw -w $WORKLOAD -host $hosts_per_edge -t $DURATION -f results/$subdir/$WORKLOAD/*/client_iperf*  \
                    results/$subdir/$WORKLOAD/max_throughput.txt -o plots/$subdir-$WORKLOAD-throughput.png
                fi

                # End Plots 

              done #protocol type (MDTCP (1), MPTCP(0) )

              if [ $mytest -eq 0 ] 
              then 
                python src/process/plot_ping_all.py -path $ping -o plots/$subdir-$WORKLOAD
                python src/process/plot_queue_cdf_all.py -path $ping -o plots/$subdir-$WORKLOAD
              fi 

            done # topology

            sleep 1
            # a=$USER
            sudo chown doljira -R results
            sudo chown doljira -R plots

      done #load for FCT test
    done #workload
  done #mytest

  m=$(( m + 1 ))

done # while

if [ $controllerId -gt 0 ] ;
then 
  kill -9 $controllerId
fi




