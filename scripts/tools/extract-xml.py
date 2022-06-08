#!/usr/bin/env python3


import argparse
import os
import os.path
import sys

import lxml.etree as ET

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("xml_file")
  parser.add_argument("-o", "--output-stem")
  args = parser.parse_args()
  
  output_stem = args.output_stem
  if output_stem == None:
    output_stem = args.xml_file[:-4]

  pair = args.xml_file.split(".")[-2]
  src,tgt = pair.split("-")

  tree = ET.parse(args.xml_file) 
  # NOTE: Assumes exactly one translation

  with open(output_stem + "." + src, "w") as ofh:
    for seg in tree.getroot().findall(".//src//seg"):
      print(seg.text, file=ofh)
  
  with open(output_stem + "." + tgt, "w") as ofh:
    for seg in tree.getroot().findall(".//ref//seg"):
      print(seg.text, file=ofh)

if __name__ == "__main__":
  main()
