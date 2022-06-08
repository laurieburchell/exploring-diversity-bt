with open("IGC1.is.phase1", 'r') as inf, open("IGC1.is.phase2", 'w') as outf:
    sent = []
    for line in inf:
        if line.startswith("</s>"):
            # write sent and start new line
            sent.append('\n')
            outf.write(" ".join(sent))
            sent = []
        else:
            sent.append(line.strip())
