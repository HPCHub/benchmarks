#!/usr/bin/python
# -*- coding: UTF-8 -*-
import os
import numpy
import sys
import argparse
import shelve

osu = ('osu_latency', 'osu_mbw_mr', 'osu_barrier', 'osu_alltoall', 'osu_allreduce')

def createParser ():
	parser = argparse.ArgumentParser()

#	parser.add_argument ('data_file', default='./', help='Path to results dat file.')
	parser.add_argument ('working_directory', default='./', help='Path to results dir.')
	parser.add_argument ('--ppn', nargs='+', type=int, \
	                      help='Space separated list of ppn for output.')
	parser.add_argument ('-N','--nodes', type=int, nargs='+', \
	                      help='Space separated list of node counts for output.')
	parser.add_argument ('--test_name', nargs='+', \
	                      choices = ['osu_latency', \
	                      'osu_mbw_mr',\
	                      'osu_alltoall', \
	                      'osu_allreduce', \
	                      'osu_barrier' \
	                      ], \
	                      help='Space separated list of tests for output.')
	parser.add_argument ('--log_sizes',  nargs='?', \
	                      help='usage: [<minlog>:<maxlog>]. This option allows you to control the lengths of the transfer messages. The output message sizes are 0, 2^minlog, ..., 2^maxlog.')
	parser.add_argument ('--decimal_separator',  type=str, default=',', \
	                      help='Decimal separator replacement.')
	return parser

def average(lst):
	lst = sorted(lst)
	if len(lst) < 1:
		return None
	if len(lst) %2 == 1:
		return lst[((len(lst)+1)/2)-1]
	else:
		return float(sum(lst[(len(lst)/2)-1:(len(lst)/2)+1]))/2.0

#чтение данных из файлов
def read_data(dir_path):
	pwd = os.getcwd()
	try:
		os.chdir(dir_path)
	except:
		print "no dir: %s" %(dir_path)
		exit(1)
	files = os.listdir('./')
	filter(lambda x: x not in ['out.log','report.time.txt'], files)

	if (len(files) == 0):
		print 'no files in '+ os.getcwd()
		exit(1)

	mteps = {}
	for k in files:
		j=k.split('.')

		name=j[0]

		if (name in osu) :
			if not name in mteps.keys():
				mteps[name]={}
			nnodes=int(j[1])
			if not nnodes in mteps[name].keys():
				mteps[name][nnodes] = {}
			ppn=int(j[2])
			if not ppn in mteps[name][nnodes].keys():
				mteps[name][nnodes][ppn]={}


		f=open(k,'r')

		find=False
		if name in ['osu_mbw_mr']:
			file_perf=mteps[name][nnodes][ppn]
			for line in f:
				if line.find('# Uni-directional Bandwidth (MB/sec)') != -1:
					find=True
					continue
				if line.find('# Message Rate Profile') != -1:
					find=False
					continue
				if find:
					str_list=line.split(' ')
					if len(str_list) == 1:
						continue
					str_list[-1]=str_list[-1].strip()
					str_list=filter(None,str_list)
					if str_list[0] == '#':
						continue
					try:
						msg_size=int(str_list[0])
						if not msg_size in file_perf.keys():
							file_perf[msg_size]=[]
						file_perf[msg_size] = map(lambda x: float(x), str_list[1:])
					except:
						pass
		elif name in ['osu_latency', 'osu_barrier', 'osu_alltoall', 'osu_allreduce']:
			file_perf=mteps[name][nnodes][ppn]
			for line in f:
				if line.find('# Size          Latency (us)') != -1:
					find=True
					continue
				if find:
					str_list=line.split(' ')
					if len(str_list) == 1:
						continue
					str_list[-1]=str_list[-1].strip()
					str_list=filter(None,str_list)
					try:
						msg_size=int(str_list[0])
						if not msg_size in file_perf.keys():
							file_perf[msg_size]=[]
						file_perf[msg_size] =  [float(str_list[1])]
					except:
						pass
		f.close()
	os.chdir(pwd)

	return mteps

def print_osu(mteps, separator, list_ppn, name , list_msg_sizes, list_nodes):
	if name in ['osu_mbw_mr']:
		for nnodes in list_nodes:
			print "test = %s, nnodes=%d " % (name,nnodes)
			print "%8s" % ('msg_size;'),
			for i in list_ppn:
				print "%7s;" % (str(i)),
			print
			for msg_size in list_msg_sizes:
				print "%7s;" % (str(msg_size)),
				for ppn in list_ppn:
					try:
						val=max(mteps[name][nnodes][ppn][msg_size])
						if val <= 99:
							print ("%7.2f;" % val).replace('.', separator),
						elif val <= 999: 
							print ("%7.1f;" % val).replace('.', separator),
						else:
							print ("%7.0f;" % val).replace('.', separator),
					except:
						print "%8s" % (';'),
				print
	else:
		for ppn in list_ppn:
			print "test = %s, ppn=%d " % (name,ppn)
			if len(list_msg_sizes) != 1 and list_msg_sizes[0] != '-1':
				print "%8s" % ('msg_size;'),
			for nnodes in list_nodes:
				print "%7s;" % (str(nnodes)),
			print
			try:
				for msg_size in list_msg_sizes:
					if len(list_msg_sizes) != 1 and list_msg_sizes[0] != '-1':
						print "%7s;" % (str(msg_size)),
					for nodes in list_nodes:
						try:
							val=average(mteps[name][nodes][ppn][msg_size])
							if val <= 99:
								print ("%7.2f;" % val).replace('.', separator),
							elif val <= 999: 
								print ("%7.1f;" % val).replace('.', separator),
							else:
								print ("%7.0f;" % val).replace('.', separator),
						except:
							print "%8s" % (';'),
					print

			except:
				print "no results for %s" % name
				print "ppn = %d " % ppn


#----------------
#MAIN PART
#----------------

parser = createParser()
namespace = parser.parse_args()


# чтение данных
mteps = read_data(namespace.working_directory)
#d = shelve.open(namespace.data_file)
#mteps = d[d.keys()[0]]
#d.close()

#определение параметров вывода
list_names={}
list_nodes={}
list_msg_sizes={}
list_ppn={}

#	формируем список тестов
list_names=mteps.keys()
if namespace.test_name:
	list_names=list(set(namespace.test_name) & set(list_names))

#	формируем список nnodes и ppn для OSU тестов
for name in list_names:
	list_nodes[name]=[]
	list_ppn[name]=[]
	list_msg_sizes[name]=[]
	list_nodes[name] = sorted(list(set(list_nodes[name]) | set(mteps[name].keys())))
	if namespace.nodes:
		set1 = set(list_nodes[name])
		set2 = set(namespace.nodes)
		list_nodes[name] = sorted(list(set1 & set2))
	for nodes in list_nodes[name]:
		if  nodes in set(mteps[name].keys()):
			set1 = set(list_ppn[name])
			set2 = set(mteps[name][nodes].keys())
			list_ppn[name] = sorted(list(set1 | set2))
	if namespace.ppn:
		set1 = set(list_ppn[name])
		set2 = set(namespace.ppn)
		list_ppn[name] = sorted(list(set1 & set2))

	for ppn in list_ppn[name]:
		for nodes in list_nodes[name]:
			set1 = set(list_msg_sizes[name])
			if ppn in mteps[name][nodes].keys():
				set2 = set(mteps[name][nodes][ppn].keys())
			else:
				set2 = set1
			list_msg_sizes[name]=sorted(list(set1 | set2))
	if namespace.log_sizes:
		msg_sizes=namespace.log_sizes.split(':')
		set1=set([2**i for i in range(int(msg_sizes[0]),int(msg_sizes[1]))])
		set2=set(list_msg_sizes[name])
		list_msg_sizes[name] = sorted(list(set1 & set2))

#вывод на экран
for name in list_names:
	print_osu(mteps, namespace.decimal_separator, list_ppn[name], name, list_msg_sizes[name] ,list_nodes[name] )


