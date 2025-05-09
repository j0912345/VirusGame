class Cell{
  int x;
  int y;
  int type;
  double wallHealth;
  Genome genome;
  double geneTimer = 0;
  double energy = 0;
  double E_RECIPROCAL = 0.3678794411;
  boolean tampered = false;
  int tampered_team = -1;
  ArrayList<ArrayList<Particle>> particlesInCell = new ArrayList<ArrayList<Particle>>(0);
  
  ArrayList<double[]> laserCoor = new ArrayList<double[]>();
  Particle laserTarget = null;
  int laserT = -9999;
  int LASER_LINGER_TIME = 30;
  String memory = "";
  /*
  0: empty
  1: empty, inaccessible
  2: normal cell
  3: waste management cell
  4: gene-removing cell
  */
  int dire;
  public Cell(int ex, int ey, int et, int ed, double ewh, String eg){
    for(int j = 0; j < 3; j++){
      ArrayList<Particle> newList = new ArrayList<Particle>(0);
      particlesInCell.add(newList);
    }
    x = ex;
    y = ey;
    type = et;
    dire = ed;
    wallHealth = ewh;
    genome = new Genome(eg,false);
    genome.rotateOn = (int)(Math.random()*genome.codons.size());
    geneTimer = Math.random()*GENE_TICK_TIME;
    energy = 0.5;
  }
  void drawCell(double x, double y, double s){
    pushMatrix();
    translate((float)x,(float)y);
    scale((float)(s/BIG_FACTOR));
    noStroke();
    if(type == 1){
      fill(60,60,60);
      rect(0,0,BIG_FACTOR,BIG_FACTOR);
    }else if(type == 2){
      if(tampered){
        fill(TAMPERED_COLOR[tampered_team]);
      }else{
        fill(HEALTHY_COLOR);
      }
      rect(0,0,BIG_FACTOR,BIG_FACTOR);
      if(this == selectedCell){
        float highlightFac = 0.5+0.5*sin(frameCount*0.5);
        fill(255,255,255,highlightFac*255);
        rect(0,0,BIG_FACTOR,BIG_FACTOR);
      }
      fill(WALL_COLOR);
      float w = (float)(BIG_FACTOR*0.08*wallHealth);
      rect(0,0,BIG_FACTOR,w);
      rect(0,BIG_FACTOR-w,BIG_FACTOR,w);
      rect(0,0,w,BIG_FACTOR);
      rect(BIG_FACTOR-w,0,w,BIG_FACTOR);
      
      pushMatrix();
      translate(BIG_FACTOR*0.5,BIG_FACTOR*0.5);
      stroke(0);
      strokeWeight(1);
      drawInterpreter();
      drawEnergy();
      genome.drawCodons(true);
      genome.drawHand();
      popMatrix();
    }
    popMatrix();
    if(type == 2){
      drawLaser();
    }
  }
  public void drawInterpreter(){
    int GENOME_LENGTH = genome.codons.size();
    double CODON_ANGLE = (double)(1.0)/GENOME_LENGTH*2*PI;
    double INTERPRETER_SIZE = 23;
    double col = 1;
    double gtf = geneTimer/GENE_TICK_TIME;
    if(gtf < 0.5){
      col = Math.min(1,(0.5-gtf)*4);
    }
    pushMatrix();
    rotate((float)(-PI/2+CODON_ANGLE*genome.appRO));
    fill((float)(col*255));
    beginShape();
    strokeWeight(BIG_FACTOR*0.01);
    stroke(80);
    vertex(0,0);
    vertex((float)(INTERPRETER_SIZE*Math.cos(CODON_ANGLE*0.5)),(float)(INTERPRETER_SIZE*Math.sin(CODON_ANGLE*0.5)));
    vertex((float)(INTERPRETER_SIZE*Math.cos(-CODON_ANGLE*0.5)),(float)(INTERPRETER_SIZE*Math.sin(-CODON_ANGLE*0.5)));
    endShape(CLOSE);
    popMatrix();
  }
  public void drawLaser(){
    if(frame_count < laserT+LASER_LINGER_TIME){
      double alpha = (double)((laserT+LASER_LINGER_TIME)-frame_count)/LASER_LINGER_TIME;
      stroke(transperize(handColor,alpha));
      strokeWeight((float)(0.033333*BIG_FACTOR));
      double[] handCoor = getHandCoor();
      if(laserTarget == null){
        for(double[] singleLaserCoor : laserCoor){
          daLine(handCoor,singleLaserCoor);
        }
      }else{
        double[] targetCoor = laserTarget.coor;
        daLine(handCoor,targetCoor);
      }
    }
  }
  public void drawEnergy(){
    noStroke();
    fill(0,0,0);
    ellipse(0,0,17,17);
    fill(255,255,0);
    pushMatrix();
    scale((float)Math.sqrt(energy));
    drawLightning();
    popMatrix();
  }
  public void drawLightning(){
    pushMatrix();
    scale(1.2);
    noStroke();
    beginShape();
    vertex(-1,-7);
    vertex(2,-7);
    vertex(0,-3);
    vertex(2.5,-3);
    vertex(0.5,1);
    vertex(3,1);
    vertex(-1.5,7);
    vertex(-0.5,3);
    vertex(-3,3);
    vertex(-1,-1);
    vertex(-4,-1);
    endShape(CLOSE);
    popMatrix();
  }
  public void iterate(){
    if(type == 2){
      if(energy > 0){
        double oldGT = geneTimer;
        geneTimer -= MOVE_SPEED;
        if(geneTimer <= GENE_TICK_TIME/2.0 && oldGT > GENE_TICK_TIME/2.0){
          doAction();
        }
        if(geneTimer <= 0){
          tickGene();
        }
      }
      genome.iterate();
    }
  }
  public void doAction(){
    useEnergy();
    Codon thisCodon = genome.codons.get(genome.rotateOn);
    int[] info = thisCodon.codonInfo;
    if(info[0] == 1 && genome.directionOn == 0){
      if(info[1] == 1 || info[1] == 2){
        Particle foodToEat = selectParticleInCell(info[1]-1); // digest either "food" or "waste".
        if(foodToEat != null){
          eat(foodToEat);
        }
      }else if(info[1] == 3){ // digest "wall"
        energy += (1-energy)*E_RECIPROCAL*0.4;
        hurtWall(26);
        laserWall();
      }else if(info[1] == 8){ // digest UGO, potentially some basic immune system simulation before I add whatever immune particles I've been thinking of
      
        /// TODO: MAKE DIGEST UGO CREATE WASTE PARTICLE
        /// <strikethru>TODO: if this does end up removing all of them, make the energy cost scale.</strikethru> this'd kinda defeat the point of it's energy restore. maybe the main focus should just be on removing ugos though.
        /// TODO: DOUBLE CHECK THAT A CELL CAN'T GAIN INFINITE ENERGY BY WRITING AND EATING UGOS IN A LOOP!
        /// TODO: make a function for handling shooting the laser at multiple coords
        /// TODO: make a nicer delete animation
        
        if(particlesInCell.get(2).size() > 0){
          laserT = frame_count;
          laserCoor.clear();
          
          energy += (1-energy)*E_RECIPROCAL*0.1;
          var currVirus = particlesInCell.get(2).get(0);
          cellCounts[7+currVirus.team]--;
          laserCoor.add(currVirus.coor);
          
          particlesInCell.get(2).get(0).removeParticle();
          
          laserTarget = null;
        }
        
        //while(particlesInCell.get(2).size() > 0){
        //  energy += (1-energy)*E_RECIPROCAL*0.1;
        //  var currVirus = particlesInCell.get(2).get(0);
        //  laserCoor.add(currVirus.coor);
        //  cellCounts[7+currVirus.team]--;
        //  // yup, doesn't use currVirus.
        //  particlesInCell.get(2).get(0).removeParticle();
        //}
      }
    }else if(info[0] == 2 && genome.directionOn == 0){
      if(info[1] == 1 || info[1] == 2){
        Particle wasteToPushOut = selectParticleInCell(info[1]-1);
        if(wasteToPushOut != null){
          pushOut(wasteToPushOut);
        }
      }else if(info[1] == 3){
        die();
      }
    }else if(info[0] == 3 && genome.directionOn == 0){ // repair?
      if(info[1] == 1 || info[1] == 2){
        Particle particle = selectParticleInCell(info[1]-1);
        shootLaserAt(particle);
      }else if(info[1] == 3){
        healWall();
      }
    }else if(info[0] == 4){ // move hand
      if(info[1] == 4){
        genome.performerOn = genome.getWeakestCodon();
      }else if(info[1] == 5){
        genome.directionOn = 1;
      }else if(info[1] == 6){
        genome.directionOn = 0;
      }else if(info[1] == 7){
        genome.performerOn = loopItInt(genome.rotateOn+info[2],genome.codons.size());
      }
    }else if(info[0] == 5 && genome.directionOn == 1){ // read
      if(info[1] == 7){
        readToMemory(info[2],info[3]);
      }
    }else if(info[0] == 6){ // write
      // writes that produce UGOs now specifically check for the new "UGO" codon operand instead of just doing that by default for any outwards write no matter the operand codon.
      if((info[1] == 7) || (genome.directionOn == 0 && info[1] == 8)){
        writeFromMemory(info[2],info[3]);
      }
    }
    genome.hurtCodons();
  }
  void useEnergy(){
    energy = Math.max(0,energy-GENE_TICK_ENERGY);
  }
  void readToMemory(int start, int end){
    memory = "";
    laserTarget = null;
    laserCoor.clear();
    laserT = frame_count;
    for(int pos = start; pos <= end; pos++){
      int index = loopItInt(genome.performerOn+pos,genome.codons.size());
      Codon c = genome.codons.get(index);
      memory = memory+infoToString(c.codonInfo);
      if(pos < end){
        memory = memory+"-";
      }
      laserCoor.add(getCodonCoor(index,genome.CODON_DIST));
    }
  }
  void writeFromMemory(int start, int end){
    if(memory.length() == 0){
      return;
    }
    laserTarget = null;
    laserCoor.clear();
    laserT = frame_count;
    if(genome.directionOn == 0){
      writeOutwards();
    }else{
      writeInwards(start,end);
    }
  }
  public void writeOutwards(){
    double theta = Math.random()*2*Math.PI;
    double ugo_vx = Math.cos(theta);
    double ugo_vy = Math.sin(theta);
    double[] startCoor = getHandCoor();
    double[] newUGOcoor = new double[]{startCoor[0],startCoor[1],startCoor[0]+ugo_vx,startCoor[1]+ugo_vy};
    Particle newUGO = new Particle(newUGOcoor,2,memory,frame_count,tampered_team);
    particles.get(2).add(newUGO);
    sfx[2].play();
    cellCounts[7+tampered_team]++; // one more virus in the cells
    newUGO.addToCellList();
    laserTarget = newUGO;
    
    var randomValue = Math.random();
    if(VIRUS_RAND_MUTATION_PERCENT_ON_REPRODUCE >=  randomValue)
    {
      newUGO.randomMutation();
    }
    
    String[] memoryParts = memory.split("-");
    for(int i = 0; i < memoryParts.length; i++){
      useEnergy();
    }
  }
  public void writeInwards(int start, int end){
    laserTarget = null;
    String[] memoryParts = memory.split("-");
    for(int pos = start; pos <= end; pos++){
      int index = loopItInt(genome.performerOn+pos,genome.codons.size());
      Codon c = genome.codons.get(index);
      if(pos-start < memoryParts.length){
        String memoryPart = memoryParts[pos-start];
        c.setFullInfo(stringToInfo(memoryPart));
        laserCoor.add(getCodonCoor(index,genome.CODON_DIST));
      }
      useEnergy();
    }
  }
  public void healWall(){
    wallHealth += (1-wallHealth)*E_RECIPROCAL;
    laserWall();
  }
  public void laserWall(){
    laserT = frame_count;
    laserCoor.clear();
    for(int i = 0; i < 4; i++){
      double[] result = {x+(i/2),y+(i%2)};
      laserCoor.add(result);
    }
    laserTarget = null;
  }
  public void eat(Particle food){
    if(food.type == 0){
      Particle newWaste = new Particle(food.coor,1,-99999);
      shootLaserAt(newWaste);
      newWaste.addToCellList();
      particles.get(1).add(newWaste);
      food.removeParticle();
      energy += (1-energy)*E_RECIPROCAL;
    }else{
      shootLaserAt(food);
    }
  }
  void shootLaserAt(Particle targetParticle){
    laserT = frame_count;
    laserTarget = targetParticle;
  }
  
  public double[] getHandCoor(){
    double r = genome.HAND_DIST;
    if(genome.directionOn == 0){
      r += genome.HAND_LEN;
    }else{
      r -= genome.HAND_LEN;
    }
    return getCodonCoor(genome.performerOn,r);
  }
  public double[] getCodonCoor(int i, double r){
    double theta = (float)(i*2*PI)/(genome.codons.size())-PI/2;
    double r2 = r/BIG_FACTOR;
    double handX = x+0.5+r2*Math.cos(theta);
    double handY = y+0.5+r2*Math.sin(theta);
    double[] result = {handX, handY};
    return result;
  }
  
  public ArrayList<Integer> getValidAdjacentParticlePushOutDires(){
    int[][] dire = {{0,1},{0,-1},{1,0},{-1,0}};
    int checkingDire = 0;
    boolean thereIsAdjacentEmptySpace = false;
    
    ArrayList<Integer> chosenValuesPrevChecked = new ArrayList<Integer>();
    ArrayList<Integer> adjacentTileTypes = new ArrayList<Integer>();
    
    for(int i = 0; i < dire.length; i++){
      // we allow removing particles by just inserting it to another adjacent cell, but only if there are no adjacent empty space tiles.
      // that should allow waste to eventually get out if there's a large chain of adjacent cells covered by walls that eventually gets to empty space.
      int currCellType = getCellTypeAt(x+dire[checkingDire][0], y+dire[checkingDire][1], true);
      if(currCellType != 1){
        chosenValuesPrevChecked.add(i);
        adjacentTileTypes.add(currCellType);
        if(currCellType == 0){
          thereIsAdjacentEmptySpace = true;
        }
      }
      checkingDire++;
    }
    // remove any other cells as valid places to insert waste into if there's adjacent empty space.
    if(thereIsAdjacentEmptySpace){
      for(int i = 0; i < chosenValuesPrevChecked.size(); i++){
        int currCellType = adjacentTileTypes.get(i);
        if(currCellType == 2){
          chosenValuesPrevChecked.remove(i);
          adjacentTileTypes.remove(i);
        }
      }
    }
    return chosenValuesPrevChecked;
  }
  
  public void pushOut(Particle waste){
    int[][] dire = {{0,1},{0,-1},{1,0},{-1,0}};
    ArrayList<Integer> validUncheckedDirections = getValidAdjacentParticlePushOutDires();
    
    if(validUncheckedDirections.size() == 0){
      return;
    }
    
    int chosenIndex = (int)random(0, validUncheckedDirections.size());
    int chosen = validUncheckedDirections.get(chosenIndex);

    double[] oldCoor = waste.copyCoor();
    for(int dim = 0; dim < 2; dim++){
      if(dire[chosen][dim] == -1){
        waste.coor[dim] = Math.floor(waste.coor[dim])-EPS;
        waste.velo[dim] = -Math.abs(waste.velo[dim]);
      }else if(dire[chosen][dim] == 1){
        waste.coor[dim] = Math.ceil(waste.coor[dim])+EPS;
        waste.velo[dim] = Math.abs(waste.velo[dim]);
      }
      waste.loopCoor(dim);
    }
    Cell p_cell = getCellAt(oldCoor,true);
    p_cell.removeParticleFromCell(waste);
    Cell n_cell = getCellAt(waste.coor,true);
    n_cell.addParticleToCell(waste);
    laserT = frame_count;
    laserTarget = waste;
  }
  public void tickGene(){
    geneTimer += GENE_TICK_TIME;
    genome.rotateOn = (genome.rotateOn+1)%genome.codons.size();
  }
  public void hurtWall(double multi){
    if(type >= 2){
      wallHealth -= WALL_DAMAGE*multi;
      if(wallHealth <= 0){
        die();
      }
    }
  }
  public void tamper(int team){
    tampered = true;
    if(tampered_team == -1 || tampered_team != team){
      cellCounts[1+tampered_team]--;
      cellCounts[1+team]++;
    }
    tampered_team = team;
  }
  public void die(){
    int freedVirusCount = particlesInCell.get(2).size();
    if(tampered_team >= 0){
      if(tampered){
        cellCounts[7+tampered_team]--; // virus in its own body is decreased by one
      }
      cellCounts[7+tampered_team] -= freedVirusCount; // viruses in the cells decreased (since they're free)
      cellCounts[5+tampered_team] += freedVirusCount; // viruses in the bloodstream increased (since they're free)
    }
    for(int i = 0; i < genome.codons.size(); i++){
      Particle newWaste = new Particle(getCodonCoor(i,genome.CODON_DIST),1,-99999);
      newWaste.addToCellList();
      particles.get(1).add(newWaste);
    }
    type = 0;
    if(this == selectedCell){
      selectedCell = null;
    }
    if(tampered && tampered_team >= 0){
      cellCounts[1+tampered_team]--;
      cellCounts[3+tampered_team]++;
    }else{
      
      cellCounts[0]--;
      cellCounts[9]++;
    }
    sfx[0].play();
    if(cellCounts[0] == 0 && cellCounts[1] == 0 && cellCounts[2] == 0){
      deathTimeStamp = frame_count;
      sfx[3].play();
    }
  }
  public void addParticleToCell(Particle food){
    particlesInCell.get(food.type).add(food);
  }
  public void removeParticleFromCell(Particle food){
    // the food variable name is possibly misleading. this could also be other particle types(?)
    ArrayList<Particle> myList = particlesInCell.get(food.type);
    for(int i = 0; i < myList.size(); i++){
      if(myList.get(i) == food){
        myList.remove(i);
      }
    }
  }
  public Particle selectParticleInCell(int type){
    ArrayList<Particle> myList = particlesInCell.get(type);
    if(myList.size() == 0){
      return null;
    }else{
      int choiceIndex = (int)(Math.random()*myList.size());
      return myList.get(choiceIndex);
    }
  }
  public String getCellName(){
    if(x == -1){
      return "Custom UGO";
    }else if(type == 2){
      return "Cell at ("+x+", "+y+")";
    }else{
      return "";
    }
  }
  public int getParticleCount(int t){
    if(t == -1){
      int sum = 0;
      for(int i = 0; i < 3; i++){
        sum += particlesInCell.get(i).size();
      }
      return sum;
    }else{
      return particlesInCell.get(t).size();
    }
  }
}
