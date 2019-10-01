#!/usr/bin/env python

import sys
import os
from pylab import plot, show, savefig, xlim, figure, \
                hold, ylim, legend, boxplot, setp, axes, subplot, ylabel, xlabel

# function for setting the colors of the box plots pairs
def setBoxColors(bp):
    setp(bp['boxes'][0], color='blue')
    setp(bp['caps'][0], color='blue')
    setp(bp['caps'][1], color='blue')
    setp(bp['whiskers'][0], color='blue')
    setp(bp['whiskers'][1], color='blue')
    setp(bp['fliers'][0], color='blue')
    setp(bp['fliers'][1], color='blue')
    setp(bp['medians'][0], color='blue')

    setp(bp['boxes'][1], color='red')
    setp(bp['caps'][2], color='red')
    setp(bp['caps'][3], color='red')
    setp(bp['whiskers'][2], color='red')
    setp(bp['whiskers'][3], color='red')
    # setp(bp['fliers'][2], color='red')
    # setp(bp['fliers'][3], color='red')
    setp(bp['medians'][1], color='red')


def myBoxplots(names, data):
  fig = figure()

  ax = subplot(1, 1, 1) # numrows, numcols, subplot index

  bp = boxplot(data, 1)
  setBoxColors(bp)

  ax.set_xticklabels(list(names))
  ylabel('Ciclos de reloj')

  # draw temporary red and blue lines and use them to create a legend
  hB, = plot([1,1],'b-')
  hR, = plot([1,1],'r-')
  legend((hB, hR),tuple(names))
  hB.set_visible(False)
  hR.set_visible(False)

  xlabel('Implementaciones')

  savefig('boxplot.png')
  show()

def main(argv):

  if len(argv) != 3:
    print("USO:\t" + argv[0] + " mediciones_implementacion_1 mediciones_implementacion_2\n")
    print("\tY mediciones_implementacion_i tiene la forma: nombre=medicion_1,medicion_2,...,medicion_n")
    print("\nEJEMPLO: para plotear dos implementaciones con 10 mediciones cada una:")
    print("\t" + argv[0] + " implementacion1=1,2,3,4,5,6,7,8,9,10 implementacion2=3,4,5,6,7,6,5,4,3,2")
    print("\nPara instalar las dependencias en Ubuntu, correr el comando:")
    print("sudo apt-get install python-numpy python-scipy python-matplotlib")
  else:
    data = []
    names = []
    for i in xrange(len(argv) - 1):
      string = argv[i+1]
      name = string.split("=")[0]
      measures = string.split("=")[1]

      names.append(name)
      data.append([float(i) for i in measures.split(",")])

    myBoxplots(names,data)

if __name__ == "__main__":
  main(sys.argv)