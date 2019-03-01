# from helper import *from collections import defaultdictimport argparseimport matplotlib.pyplot as pltparser = argparse.ArgumentParser()# parser.add_argument('-p', '--port', dest="port", default='5001')parser.add_argument('-f', dest="files", nargs='+', required=True)parser.add_argument('-o', '--out', dest="out", default=None)# parser.add_argument('-H', '--histogram', dest="histogram",#                     help="Plot histogram of sum(cwnd_i)",#                     action="store_true",#                     default=False)args = parser.parse_args()def first(lst):    return map(lambda e: e[0], lst)def second(lst):    return map(lambda e: e[1], lst)"""Sample line:2.221032535 10.0.0.2:39815 10.0.0.1:5001 32 0x1a2a710c 0x1a2a387c 11 2147483647 14592 85"""def parse_file(f):    cwnd = defaultdict(list)    for l in open(f).xreadlines():        fields = l.strip().split(' ')        # print((fields))        if '127.0.0.1' in l:            continue        elif int(fields[3]) == 32 or int(fields[3])==40:            srcdst=fields[1]+'_'+fields[2]            # and int(fields[6])==10            if srcdst not in cwnd.keys():                cwnd[srcdst]={'cwnd':[int(fields[6])],'rtt':[int(fields[9])],'time':[float(fields[0])]}            elif srcdst in cwnd.keys():                cwnd[srcdst]['cwnd'].append(int(fields[6]))                cwnd[srcdst]['rtt'].append(int(fields[9]))                cwnd[srcdst]['time'].append(float(fields[0]))                print(len(cwnd.keys()))    return cwnd# added = defaultdict(int)# events = []def plot_cwnds():    font = {'family' : 'sans serif','weight' :'normal','size': 12}    plt.rc('font', **font)    colors=['blue','red','green','black','magenta','cyan','yellow','orange','purple']    fig = plt.figure()    axPlot = fig.add_subplot(111)    i=0    j=0    k=0       for f in args.files:        cwnds = parse_file(f)        for cwnd in sorted(cwnds.keys()):            if len (cwnds[cwnd]['cwnd'])> 10:                if '10.0.0.2' in cwnd:                    axPlot.plot(cwnds[cwnd]['time'],cwnds[cwnd]['cwnd'],linewidth=3,color=colors[i],label='CWND1-SF'+str(k+1))                    i+=1                    k+=1                elif '10.0.0.3' in cwnd:                    axPlot.plot(cwnds[cwnd]['time'],cwnds[cwnd]['cwnd'],linewidth=3,color=colors[i],label='CWND2-SF'+str(j+1))                    i+=1                    j+=1                                            axPlot.set_xlabel('Time [secs]')    axPlot.set_ylabel('CWND [Pkts]')    axPlot.set_ylim(0,30)    plt.legend(loc='upper right',ncol=2)    axPlot.grid(True)    plt.savefig('dctcp-cwnd.pdf')    plt.show()plot_cwnds()