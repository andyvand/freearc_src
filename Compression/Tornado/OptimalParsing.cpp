main
{
    // 1. ��������� ��������� �����
    for (i=0; i<CHUNK; i++)
    {
        matches[i] = matchp;                  // ��������� ������ �� ������ ���� ��� ���� �������
        matchp = fill_matches(buf,i,matchp);  // ��������� ��� ����� ���� ������� � �������� �� � �����
    }
    // 1.5 ��������� ������ matches �������� �� 2/3-�������� ������
    // 2. ������� ��������� ���� �����
    iterate (CHUNK, price[i]=INT_MAX);  price[0]=0;
    for (i=0; i<CHUNK; i++)
    {
        suggest (i+1, 1, buf[i], price[i] + charPrice(buf[i]));  // ���������� �� ������� i+1 ������� ���� + ������
        lastlen = MINMATCH-1;
        for (our matches)
            while (++lastlen <= len)   // �������� ��� �������� �� ����� ����. ����� �� ����� ��������� (todo: if len>256, ��������� ������ � ��������� 128 ��������� � ����������� �� ����������)
            {
                // todo: ���� ��������� ��������� � ����� �� 4 ����������, �� ���� ����� ������..
                suggest (i+lastlen, lastlen, dist, price[i] + matchPrice(lastlen,dist)); // ���� = ���� �������� ����� + ����������� ������
            }
    }
    // 3. �������� ����������� ���� �� ����� � ������
    for (i=CHUNK-1; i; i-=len[i])
    {
        push (len[i], dist[i]);
    }
    // 4. ������������ ��������� ���� � ��������
    while (stack not empty)
    {
        len, dist = pop();
        encode (len,dist);
    }
}

suggest (i, len, dist, match_price)
{
    if (price[i] < match_price)        // ����� ������� �������� �������
    {
        price[i] = match_price;
        len[i]  = len;
        dist[i] = dist;
    }
}
