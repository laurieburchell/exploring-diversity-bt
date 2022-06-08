"""
Created on Mon Dec 13 10:27:02 2021

@author: laurie
"""
from nltk.tree import Tree as NLTKTree
from . import tree_kernels
from . import tree
import re

class SSTKernelFromString(tree_kernels.KernelSST):
    def __init__(self, l=1, hashsep="#"):
        self.l = float(l)
        self.hashsep = hashsep
        self.cache = tree_kernels.Cache()
        
    
    def printree(self, nltk_tree):
        """
        print nltk tree into prolog style
        Example "predicate(arg1, arg2)"
        """
        if isinstance(nltk_tree, NLTKTree):
            leaves = [self.printree(leave) for leave in nltk_tree]
            return f"{nltk_tree.label()}({','.join(leaves)})"
        else:
            return nltk_tree
        
    def remove_leaves(self, treestring):
        """Removes leaves from string representation of tree"""
        wintertree = re.sub(r' \w+\)', " blah)", treestring)
        
        return wintertree
        
    def string_to_tree(self, treestring):
        """
        convert CFG one-line string to tree
        """
        
        nltktree = NLTKTree.fromstring(treestring)
        prologstring = self.printree(nltktree)
        treerep = tree.Tree.fromPrologString(prologstring)
        
        return treerep
    
    def calculate_kernel(self, treestring1, treestring2, 
                         norm=True, removeleaves=True):
        """Calculates tree kernel from string representations"""
        
        if removeleaves:
            wintertree1 = self.remove_leaves(treestring1)
            tree1 = self.string_to_tree(wintertree1)
            wintertree2 = self.remove_leaves(treestring2)
            tree2 = self.string_to_tree(wintertree2)
            
        else:
            tree1 = self.string_to_tree(treestring1)
            tree2 = self.string_to_tree(treestring2)
            
        k = self.kernel(tree1, tree2)
        
        if norm and k != 0:
            denom =  (self.kernel(tree1, tree1) \
                      * self.kernel(tree2, tree2)) ** (0.5)
            k = k / denom
            
        return k

#if __name__ == "__main__":
#    print("running test sequence")
#    # two string representations of parse trees to work with
#    treestring1 = "(ROOT (S (NP (NNP Schools)) (VP (VBD urged) (S (VP (TO to) (VP (VB focus) (NP (JJR more)) (PP (IN on) (NP (NNS maths) (, ,) (NN spelling) (CC and) (NN grammar)))))))))"
#    treestring2 = "(ROOT (S (NP (DT A) (VBN combined) (JJ English) (NN literature) (CC and) (NN language) (NN course)) (VP (MD will) (VP (VB be) (VP (VBN scrapped)))) (. .)))"
#    
#    kern = SSTKernelFromString()
#    k = kern.calculate_kernel(treestring1, treestring2)
#    k2 = kern.calculate_kernel(treestring2, treestring1)
#    print(k)
#    print(k2)
