# CS3220 Lab #2 : Branch Prediction

100 pts in total, will be rescaled into 11.25% of your final score of the course.  

**Part 1: Baseline Branch Predictor**: 60 pts

**Part 2: Performance Measurement & Optimization**: 40 pts + 10 bonus pts

***Submission ddl***: Oct 2nd

This lab is a continuation of lab #1. In this project, you will implement a branch predictor for your RISC-V CPU. You are suggested to work on top of the solution for lab #1 from the TAs, which are located in the current folder. Alternatively, you can copy your *.v and *.vh files from lab #1 and start from your own implementation.

## Part 1: Baseline Branch Predictor (60 points): 

In this part, you'll be implementing a baseline branch predictor and a branch target buffer for your RISC-V CPU. Here's a concise overview of the design: 

The baseline design adopts a G-share branch predictor (please refer to lecture-8's slides page 54): 

1. Its branch history register (BHR) has a length of 8 bits, you will use `PC[9:2] XOR BHR` to index a Pattern History Table (PHT), which is composed of 2^8 2-bit counters for branch prediction. Each counter is initialized with 1 (indicating a weakly not taken).

2. The branch target buffer (BTB) has 16 entries, and you will use `PC[5:2]` to index it.

Summary of the G-share branch prediction algorithm: 

* FE Stage ([fe_stage.v](fe_stage.v)): 

    Both BTB and PHT are concurrently accessed in this stage. 
    
    1. If there's a BTB hit, use PHT outcome to determine the target address for the next fetch: if the outcome is taken, use BTB target address. If BTB misses, use PC+4 for next instruction. 

    2. The index (`PC[9:2] XOR BHR`) used in FE stage is passed to EX stage for PHT update.

* EX stage ([agex_stage.v](agex_stage.v)): 

    1. If the predicted address is incorrect, flush the pipeline.

    2. For branch instructions (bne, beq, jalr, etc.), insert the target address into the BTB, whether taken or not.
    
    3. If PHT is used for branching prediction in the FE stage, update PHT using the propagated PHT index (`PC[9:2] XOR BHR`). 

    4. Update the BHR. 

To pass this part and earn full credit, implement the baseline branch predictor described above and run your baseline branch predictor on [testall.mem](/test/part4/testall.mem) and ensure it passes this testcase.

<!-- **Grading**:
We will check whether </test/part4/testall.mem> is correctly executed or not. 
There won’t be any performance improvement in testall.mem because the final execution time is already fixed by the test code.  With the branch predictor/BTB, your code should finish testall.mem correctly. 

**What to submit:**
**A zip file of your source code. The zip file must contain the following:**
type ```make submit``` will generate a submission.zip. 
Please submit the submission.zip file. Each submission for each group. -->


## Part 2: Performance Measurement & Optimization (40 points + 10 bonus pts)

1. [10 pts] For this part, you will evaluate branch prediction accuracy by adding counters to measure it (# of correctly predicted branches / # total branch instructions). Utilize the [towers.mem](test/towers/towers.mem) testcase for this assessment and write your measurement results in a pdf report.

2. [30 pts + 10 pts bonus] Enhance the performance of your branch predictor on the [towers.mem](test/towers/towers.mem) testcase by making design changes: you can explore other BHR hashing functions (e.g. using different bits of PC for the XOR operation), or change the PHT or BTB sizes. Implement at least three different design changes, and present the corresponding performance outcomes in your report. If your modifications result in more than a 5% increase in prediction accuracy compared to the baseline branch predictor, you will earn 10 bonus points.

## Submission

+ Provide a zip file containing your source code for Part 1. Generate the submission.zip file using the command make submit. Avoid manual zip file creation to prevent any issues with the autograding script, which could lead to a 30% score deduction.

+ Submit a concise PDF report for Part 2 (limited to 2 pages) containing the following information:
1.  Your performance measurements for the baseline G-share branch predictor and your three variants.
2.  Discuss the design parameters that were modified and explain how these changes influenced branch prediction accuracy, either positively or negatively.

<!-- Your scores will be depending on the performance improvement. If you get more than 5% performance improvement over the baseline configuration, you will receive 2 pts, if not, you will get 1 pt based on your report contents.  
Discuss your design space explorations and write a report about your evaluations. 
Evaluate your design with the provided benchmark and report the performance numbers. 
Please print out cycle count, BP accuracy (# of corrected predicted branch/# branch insts), # taken branches, # not-taken branches. # branches.  The cases are no branch predictor, baseline branch predictor (part-1), and your improved versions. Please show the results those are hurting the performance. 
Please show at least 3 different design changes that you have made in addition to the baseline branch predictor. Total 4 branch predictor's results + no branch predictor's result (project #1).  -->

<!-- **Grading**
The contents of the report will be used for the grading part-2.  
Please discuss what design parameters have you changed and discuss why it changes (good or bad or the same) performance.  


**What to submit** 
Report (max 2 pages) (No need to submit the code again)  -->

## FAQ 

[Q] I passed [testall.mem](test/part4/testall.mem) but failed to pass some testcases under [test/part2](test/part2). What should I do? \
[A] Please carefully check whether your when-to-flush logic is correctly implemented in the AGEX stage based on the following criteria: When should we flush the pipeline? If the branch is not taken, and next instruction we fetched is not PC+4, we should flush the pipeline; if the branch is taken, and the next instruction we fetched is not the branch target, we are supposed flush the pipeline as well.


[Q]  I’m debugging my code. I see that there is an X in the BTB. How would it be possible? \
[A] FE stage can have pipeline bubbles. BTB/BHT might be indexed with uninitialized values. Please also make it sure when you update BTB/BHT, only branch instructions/signals (not including X) can change the BTB/BHT values.

[Q] I don’t see performance improvement in testall.mem. Why ?  \
[A]  All branch code in testall.mem are executed only once and not-taken. In order to make a branch predictor work, the processor has to see the same branch over and over. W/o training, the branch predictor would’t work well. 

[Q] Do we insert a BTB entry only for the taken branch or even for not-taken a branch? \
[A] You insert a BTB entry even for the not-taken branch. Because the same branch might be taken in the next time prediction. 

[Q] If we insert a not-taken branch for the BTB entry, what will be the target address? \
[A] You can compute the potential target address and insert it in the BTB. 

[Q] What if the target in the BTB is wrong? \
[A] Just like a branch misprediction, we flush the pipeline and also update the BTB with the correct information. 

[Q] With a branch predictor, will the pipeline still have pipeline bubbles?  \
[A] The pipeline will have pipeline bubble for dependency stalls but not for branch instructions. 

[Q] My pipeline did not work for lab 1. What should I do?  \
[A] Please use the reference design provided by TAs instead. 

[Q] I want to add a new file (bp.v). can I? \
[A] Please do not add new file, as it might break our auto-grading script. 

[Q] Do I have to show the performance improvement in order to get a full-credit for part 1? \
[A] No. the performance improvement needs to be demonstrated in part 2 only. 

[Q] Are we expected to implement data forwarding in lab 2? \
[A] No.

[Q] Let’s say my instruction stream is as follows: 
```
BR(1)
ADD
BR(2)
```
. When BR(1) is in EX, it will update the BHR. But BR(2) will be in FE at that time.
Which value of BHR should FE use? The old value or the updated value from EX? \
[A] This is one of the optimization opportunities. So how you handle this case is up to you. Please remember that the branch predictor is just a predictor and it won't affect the correctness of the program. 

[Q] How to initialize PHT as one? \
[A] You should explicitly put 1s when it resets. 

[Q] I ran tower.mem and my test case is failed unlike other test cases. Is that expected?\
[A] Yes. The tower.mem returns "255", which does not match the PASS criteria of the simulator. You do not need to worry about it.
