import subprocess
import os
import fcntl
import base64
import select

d0_blind_id_keygen = "./crypto-keygen-standalone"
d0_blind_id_d0pk = "key_0.d0pk"

def d0_blind_id_verify(sig, querystring, postdata=None): #-> (idfp, status)
	data = None
	if postdata == None:
		data = querystring
	else:
		data = postdata + "\0" + querystring
	if sig != None:
		# make some pipes
		(dpipe_r, dpipe_w) = os.pipe()
		(spipe_r, spipe_w) = os.pipe()

		# smoke them
		def closepipes():
			os.close(dpipe_w)
			os.close(spipe_w)
		checker = subprocess.Popen([d0_blind_id_keygen, "-p", d0_blind_id_d0pk, "-d", "/dev/fd/%d" % (dpipe_r, ), "-s", "/dev/fd/%d" % (spipe_r, )], stdout=subprocess.PIPE, preexec_fn=closepipes)

		# close them
		os.close(dpipe_r)
		os.close(spipe_r)

		# make them nonblocking
		fcntl.fcntl(dpipe_w, fcntl.F_SETFL, fcntl.fcntl(dpipe_w, fcntl.F_GETFL) | os.O_NONBLOCK)
		fcntl.fcntl(spipe_w, fcntl.F_SETFL, fcntl.fcntl(spipe_w, fcntl.F_GETFL) | os.O_NONBLOCK)

		# fill vars
		rpipes = [dpipe_w, spipe_w]
		buffers = [data, base64.b64decode(sig)]

		# generic nonblocking buffer loop
		while len([p for p in rpipes if p != None]) != 0:
			(readers, writers, errorers) = select.select([], [p for p in rpipes if p != None], [p for p in rpipes if p != None], None)
			n = 0
			for e in errorers:
				i = [j for j in range(len(rpipes)) if rpipes[j] == e]
				if len(i) != 1:
					continue
				i = i[0]
				os.close(e)
				buffers[i] = None
				rpipes[i] = None
				n += 1
			for w in writers:
				i = [j for j in range(len(rpipes)) if rpipes[j] == w]
				if len(i) != 1:
					continue
				i = i[0]
				written = os.write(w, buffers[i])
				if written > 0:
					buffers[i] = buffers[i][written:]
				if buffers[i] == "":
					os.close(w)
					buffers[i] = None
					rpipes[i] = None
				n += 1
			if not n:
				break

		# close all remaining
		for p in rpipes:
			if p != None:
				os.close(p)

		# check
		if len([x for x in buffers if x != None]) != 0:
			raise Exception("could not write data to process")

		# retrieve data from stdout
		status = checker.stdout.readline().rstrip("\n")
		idfp = checker.stdout.readline().rstrip("\n")
		checker.stdout.close()
		checker.wait()
		if checker.returncode != 0:
			return (None, None)
		return (idfp, (status == "1"))

if __name__ == "__main__":
	sig = "gQEBERjDsnVNr4qrYkvaevguF4ypPZHq0yiXfMMKwlu7+kY3HuI8zHx2WhiYj+q26re5uamQ9r8umh54CEJ7zqZAz8IavVblWYznzee9WjIBAB1FeHwILGlKOCDpGBikoZBkMxI4MqjCPzDPAkDMrd1DK0FsWOTpWljLgNGfACTKcgKBAQGPqnGoD6GhuHLYN+Sf73ROColneBdJ7ttuVwm32FvI8LuD5aLDll7bpqfHTWhgbTW02CYvkTAYtoz2RZmIGK5ZHHaM/V6vcSXnq2ab/7mFRiag7D5OUsmIFY9E3IqcqtP7+wXSVgiNFY3DBPy27bXjk8ZJ9nUD5dQBL9sG8TzWd4EBAYrTMfF82EBgsVArIaQjeOuJC3bkPzP5b3El/ZCHkDShpu7wZ82h/82B4W5Ep3KXpgu+YAEULt+5i2WbsfRSXeVZctzD4A++MBqQx9VuN/KsxgHS/20tRiBgd1VElhRD8KJ0lbkxYNcHSkpWSMDFS+eFmizcM3/XQNQ7ukAmM3lkgQEBIZR+FpDFLoGg9mIu2RH9O7lWdifpVhqjrEnvkr4KdB6JzBXAwVPmt1NAVDjGRI/ELlTysOx1b9F2EgdJejY5LgcVxz6irwEckx0z+L10A6Ca2lsGR1E+rViFffNNIJv34dNKgaCInyUNCeBei0AF8KLXLHhRTiBvSVBi6ANb/lY="
	querystring = ""
	postdata = "hello world"
	(idfp, status) = d0_blind_id_verify(sig, querystring, postdata)
	print(repr((idfp, status)))
