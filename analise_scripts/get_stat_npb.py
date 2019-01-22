#!/usr/bin/python
# -*- coding: UTF-8 -*-
import os
import numpy
import sys
import argparse
import shelve
from math import sqrt

npb = ('is', 'ft','cg', 'mg', 'lu', 'ep', 'sp', 'bt')
#osu = ('osu_latency', 'osu_mbw_mr', 'osu_barrier', 'osu_alltoall', 'osu_allreduce')

def createParser ():
	parser = argparse.ArgumentParser()

#	parser.add_argument ('data_file', default='./', help='Path to results dat file.')
	parser.add_argument ('working_directory', default='./', help='Path to results dir.')
	parser.add_argument ('--ppn', nargs='+', type=int, \
	                      help='Space separated list of ppn for output.')
	parser.add_argument ('-N','--nodes', type=int, nargs='+', \
	                      help='Space separated list of node counts for output.')
	parser.add_argument ('--test_name', nargs='+', \
	                      choices = ['is', 'ft', 'lu', 'cg', 'mg', 'ep', 'sp', 'bt' ], \
	                      help='Space separated list of tests for output.')
#	parser.add_argument ('--log_sizes',  nargs='?', \
#	                      help='usage: [<minlog>:<maxlog>]. This option allows you to control the lengths of the transfer messages. The output message sizes are 0, 2^minlog, ..., 2^maxlog.')
	parser.add_argument ('--npb_classes',  type=str, choices=['A', 'B', 'C', 'D', 'E'], \
	                      help='Space separated list of sizes for NPB test.')
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
#возвращает: mteps[npb_class][name][nnodes][ppn]=perfomance
def read_data(dir_path):
	pwd = os.getcwd()
	try:
		os.chdir(dir_path)
	except:
		print "no dir: %s" %(dir_path)
		exit(1)
	mteps = {}
	for path, subdirs, files in os.walk('./'):
		files=list(filter(lambda x: x not in ['out.log','report.time.txt'], files))
		if (len(files) == 0):
			continue

		for k in files:
			j=k.split('.')

			name=j[0]

			if (name in npb):
				npb_class=j[1]
				if (not npb_class in mteps.keys()):
					mteps[npb_class]={}
				if (not name in mteps[npb_class].keys()):
					mteps[npb_class][name]={}
				nnodes=int(j[2])
				if (not nnodes in mteps[npb_class][name].keys()):
					mteps[npb_class][name][nnodes] = {}
				ppn=int(j[3])
				if (not ppn in mteps[npb_class][name][nnodes].keys()):
					mteps[npb_class][name][nnodes][ppn]=[]
				iter=int(j[4])


			f=open(os.path.join(path,k),'r')

			find=False
			if (name in npb):
				for line in f:
					if line.find('Mop/s total') != -1:
						ind=line.find('=')
						val=float(line[ind+1:])
						mteps[npb_class][name][nnodes][ppn].append(val)
			f.close()
	os.chdir(pwd)
	return mteps

# Calculates the sample standard deviation for a list of numbers.
def sample_standard_deviation(lst):
	num_items = len(lst)
	mean = sum(lst) / num_items
	differences = [x - mean for x in lst]
	sq_differences = [d ** 2 for d in differences]
	ssd = sum(sq_differences)
	if num_items == 1:
		variance = ssd / (num_items )
	else:
		variance = ssd / (num_items - 1)
	sd = sqrt(variance)
	return sd

#FIXME: don't support for sp and bt tests
def print_npb(mteps, separator, list_name, npb_class, ppn, list_nnodes):
	if (ppn in [2 ** i for i in range(10)]):
#	производительность
		print "-----------------"
		print "perfomance"
		print "%s;%s; "%("", ""),
		for nnodes in list_nnodes:
			print "%s;%s;%s; " % ("",nnodes,""),
		print
	
		print "%s;%s; "%("name", "ppn"),
		for nnodes in list_nnodes:
			print "%5s;%3s;%6s;%7s;%5s; " % ("niters","max","min","avg","ssd(%)"),
		print
		for name in (set(list_name) & {'is','lu','ft','mg','cg','ep','sp','dt'}):
			print "%4s;" % (name),
			print "%2d;" % (ppn),
			for nnodes in list_nnodes:
				try:
					min_val=min(mteps[npb_class][name][nnodes][ppn])
					max_val=max(mteps[npb_class][name][nnodes][ppn])
					avg_val=average(mteps[npb_class][name][nnodes][ppn])
					dev=sample_standard_deviation(mteps[npb_class][name][nnodes][ppn])/avg_val*100
					print ("%2d;%7.0f;%7.0f;%7.0f;%6.2f;" % (len(mteps[npb_class][name][nnodes][ppn][:]), max_val,min_val, avg_val, dev)).replace('.', separator),
				except:
					print ";;;",
			print
#		ускорение
		print "-----------------"
		print "speedup"
		print "%s;%s; "%("", ""),
		for nnodes in list_nnodes:
			print "%s;%s; " % ("",nnodes),
		print
	
		print "%s;%s; "%("name", "ppn"),
		for nnodes in list_nnodes:
			print "%6s;%6s; " % ("niters","avg"),
		print
		for name in  (set(list_name) & {'is','lu','ft','mg','cg'}):
			print "%4s;" % (name),
			print "%2d;" % (ppn),
			try:
				avg_val0 = average(mteps[npb_class][name][1][ppn][:])
			except:
				print "NO speedup for %s" % name
				continue

			for nnodes in list_nnodes:
				try:
					min_val=min(mteps[npb_class][name][nnodes][ppn])
					max_val=max(mteps[npb_class][name][nnodes][ppn])
					avg_val=average(mteps[npb_class][name][nnodes][ppn])
					print ("%7d;%6.2f;" % (len(mteps[npb_class][name][nnodes][ppn][:]), avg_val/avg_val0 )).replace('.', separator),
				except:
					print "%7s;%6s;" %(" ", " "),
			print
		print "-----------------"

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
list_npb_classes={}

#	формируем список размеров задач для NPB
list_npb_classes=mteps.keys()
if namespace.npb_classes:
	list_npb_classes=list(set(namespace.npb_classes) & set(list_npb_classes))

#	формируем список тестов
for npb_class in list_npb_classes:
	list_names[npb_class] = []
	list_names[npb_class] = mteps[npb_class].keys()
	if namespace.test_name:
		set1 = set(list_names[npb_class])
		set2 = set(namespace.test_name)
		list_names[npb_class] = list(set1 & set2)

#	формируем список nnodes и ppn для NPB тестов
for npb_class in list_npb_classes:
	list_nodes[npb_class]=[]
	list_ppn[npb_class]=[]
	for name in (set(list_names[npb_class]) & set(npb)):
		list_nodes[npb_class] = sorted(list(set(list_nodes[npb_class]) | set(mteps[npb_class][name].keys())))
		if namespace.nodes:
			set1 = set(list_nodes[npb_class])
			set2 = set(namespace.nodes)
			list_nodes[npb_class] = sorted(list(set1 & set2))

		for name in (set(list_names[npb_class]) & set(npb)):
			for nodes in list_nodes[npb_class]:
				if (nodes in set(mteps[npb_class][name].keys())):
					set1 = set(list_ppn[npb_class])
					set2 = set(mteps[npb_class][name][nodes].keys())
					list_ppn[npb_class] = sorted(list(set1 | set2))
		if namespace.ppn:
			set1 = set(list_ppn[npb_class])
			set2 = set(namespace.ppn)
			list_ppn[npb_class] = sorted(list(set1 & set2))

#вывод на экран
for npb_class in list_npb_classes:
	for ppn in list_ppn[npb_class]:
		print_npb(mteps, namespace.decimal_separator, list(set(list_names[npb_class]) & set(npb)), npb_class, ppn, list_nodes[npb_class] )


